//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// The span processor used internally by Embrace.
package class EmbraceSpanProcessor: SpanProcessor {

    let nameLengthLimit = 128

    let spanExporters: [SpanExporter]
    internal let processorQueue = DispatchQueue(label: "io.embrace.spanprocessor", qos: .utility)
    let resourceProvider: (() -> Resource?)?
    private weak var logger: InternalLogger? = nil
    let sessionIdProvider: (() -> String?)?
    let criticalResourceGroup: DispatchGroup?

    weak var sdkStateProvider: EmbraceSDKStateProvider?

    @ThreadSafe var autoTerminationSpans: [SpanId: SpanAutoTerminationData] = [:]

    /// Returns a new EmbraceSpanProcessor that converts spans to SpanData and forwards them to
    public init(
        spanExporters: [SpanExporter],
        sdkStateProvider: EmbraceSDKStateProvider,
        logger: InternalLogger? = nil,
        sessionIdProvider: (() -> String?)? = nil,
        criticalResourceGroup: DispatchGroup? = nil,
        resourceProvider: (() -> Resource?)? = nil
    ) {
        self.spanExporters = spanExporters
        self.sdkStateProvider = sdkStateProvider
        self.logger = logger
        self.sessionIdProvider = sessionIdProvider
        self.resourceProvider = resourceProvider
        self.criticalResourceGroup = criticalResourceGroup
    }

    /// Returns a new EmbraceSpanProcessor that converts spans to SpanData and forwards them to
    public convenience init(
        spanExporter: SpanExporter,
        sdkStateProvider: EmbraceSDKStateProvider,
        logger: InternalLogger? = nil,
        sessionIdProvider: (() -> String?)? = nil,
        criticalResourceGroup: DispatchGroup? = nil,
        resourceProvider: (() -> Resource?)? = nil
    ) {
        self.init(
            spanExporters: [spanExporter],
            sdkStateProvider: sdkStateProvider,
            logger: logger,
            sessionIdProvider: sessionIdProvider,
            criticalResourceGroup: criticalResourceGroup,
            resourceProvider: resourceProvider
        )
    }

    public func autoTerminateSpans() {
        let now = Date()

        for data in autoTerminationSpans.values {
            data.span.setAttribute(key: SpanSemantics.keyErrorCode, value: data.code)
            data.span.status = .error(description: data.code)
            data.span.end(time: now)
        }

        autoTerminationSpans.removeAll()
    }

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: OpenTelemetrySdk.ReadableSpan) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        let data = span.toSpanData()
        processIncompletedSpanData(data, span: span, sync: false)
    }

    public func onEnd(span: OpenTelemetrySdk.ReadableSpan) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        let data = span.toSpanData()
        processCompletedSpanData(data)
    }

    public func flush(span: OpenTelemetrySdk.ReadableSpan) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        let data = span.toSpanData()
        processIncompletedSpanData(data, span: span, sync: true)
    }

    public func forceFlush(timeout: TimeInterval?) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        let exporters = self.spanExporters
        processorQueue.sync {
            for exporter in exporters {
                _ = exporter.flush(explicitTimeout: timeout)
            }
        }
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        let exporters = self.spanExporters
        processorQueue.sync {
            for exporter in exporters {
                exporter.shutdown()
            }
        }
    }

    internal func processIncompletedSpanData(_ data: SpanData, span: ReadableSpan?, sync: Bool) {
        // cache if flagged for auto termination
        if let span, let code = autoTerminationCode(for: data, parentId: data.parentSpanId) {
            autoTerminationSpans[data.spanId] = SpanAutoTerminationData(
                span: span,
                spanData: data,
                code: code,
                parentId: data.parentSpanId
            )
        }

        runExporters(data, sync: sync)
    }

    internal func processCompletedSpanData(_ spanData: SpanData) {
        var data = spanData
        if data.hasEnded && data.status == .unset {
            if let errorCode = data.errorCode {
                data.settingStatus(.error(description: errorCode.rawValue))
            } else {
                data.settingStatus(.ok)
            }
        }

        runExporters(data, sync: false)
    }

    private func runExporters(_ span: SpanData, sync: Bool) {
        runExporters([span], sync: sync)
    }

    private func hydrateSpan(_ span: SpanData, with resource: Resource?) -> SpanData? {

        // spanData endTime is non-optional and will be set during `toSpanData()`
        let endTime = span.hasEnded ? span.endTime : nil

        // Prevent exporting our session spans on end.
        // This process is handled by the `SessionController` to prevent
        // race conditions when a session ends and its payload gets built.
        if endTime != nil && span.embType == SpanType.session {
            return nil
        }

        var spanData = span

        // sanitize name
        let spanName = sanitizedName(span.name, type: span.embType)
        guard !spanName.isEmpty else {
            logger?.warning("Can't export span with empty name!")
            return nil
        }
        if spanName != span.name {
            spanData = spanData.settingName(spanName)
        }

        // add session id attribute
        if let sessionId = sessionIdProvider?() {
            var attributes = spanData.attributes
            attributes[SpanSemantics.keySessionId] = .string(sessionId)
            spanData = spanData.settingAttributes(attributes)
        }

        // add resource
        if let resource {
            spanData = spanData.settingResource(resource)
        }

        return spanData
    }

    private func runExporters(_ spans: [SpanData], sync: Bool) {

        let exporters = self.spanExporters
        var spansToExport: [SpanData] = spans
        let provider = resourceProvider

        let block = { [self] in
            let resource = provider?()
            spansToExport = spansToExport.compactMap { hydrateSpan($0, with: resource) }
            for exporter in exporters {
                _ = exporter.export(spans: spansToExport)
            }
        }

        if sync {
            processorQueue.sync {
                block()
            }
        } else {
            processorQueue.async { [self] in
                criticalResourceGroup?.wait()
                block()
            }
        }

    }

    // finds the auto termination code from the span's attributes
    // also tries to find it from it's parent spans
    private func autoTerminationCode(for data: SpanData, parentId: SpanId? = nil) -> String? {
        if let code = data.attributes[SpanSemantics.keyAutoTerminationCode] {
            return code.description
        }

        if let parentId = parentId,
            let parentData = autoTerminationSpans[parentId]
        {
            return autoTerminationCode(for: parentData.spanData, parentId: parentData.parentId)
        }

        return nil
    }

    func sanitizedName(_ name: String, type: SpanType) -> String {

        // do not truncate specific types
        guard type != .networkRequest,
            type != .view,
            type != .viewLoad
        else {
            return name
        }

        var result = name

        // trim white spaces
        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
        result = name.trimmingCharacters(in: trimSet)

        // truncate
        if result.count > nameLengthLimit {
            result = String(result.prefix(nameLengthLimit))
            logger?.warning("Span name is too long and has to be truncated!: \(name)")
        }

        return result
    }
}

struct SpanAutoTerminationData {
    let span: ReadableSpan
    let spanData: SpanData
    let code: String
    let parentId: SpanId?

    init(span: ReadableSpan, spanData: SpanData, code: String, parentId: SpanId? = nil) {
        self.span = span
        self.spanData = spanData
        self.code = code
        self.parentId = parentId
    }
}
