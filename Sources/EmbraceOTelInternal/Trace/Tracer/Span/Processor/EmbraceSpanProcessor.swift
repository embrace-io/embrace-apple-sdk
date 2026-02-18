////
////  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
////
//
//import Foundation
//import OpenTelemetryApi
//import OpenTelemetrySdk
//
//#if !EMBRACE_COCOAPOD_BUILDING_SDK
//    import EmbraceCommonInternal
//    import EmbraceSemantics
//#endif
//
///// The span processor used internally by Embrace.
//package class EmbraceSpanProcessor: SpanProcessor {
//
//    let nameLengthLimit = 128
//
//    let spanProcessors: [SpanProcessor]
//    let embraceExporter: StorageSpanExporter?
//    let spanExporters: [SpanExporter]
//    package let processorQueue = DispatchQueue(label: "io.embrace.spanprocessor", qos: .utility)
//    let resourceProvider: (() -> Resource?)?
//    private weak var logger: InternalLogger? = nil
//    let sessionIdProvider: (() -> String?)?
//    let criticalResourceGroup: DispatchGroup?
//
//    weak var sdkStateProvider: EmbraceSDKStateProvider?
//
//    private let _autoTerminationSpans = EmbraceMutex<[SpanId: SpanAutoTerminationData]>([:])
//    var autoTerminationSpans: [SpanId: SpanAutoTerminationData] {
//        _autoTerminationSpans.withLock { $0 }
//    }
//
//    /// Returns a new EmbraceSpanProcessor that converts spans to SpanData and forwards them to
//    public init(
//        spanProcessors: [SpanProcessor] = [],
//        spanExporters: [SpanExporter] = [],
//        sdkStateProvider: EmbraceSDKStateProvider,
//        logger: InternalLogger? = nil,
//        sessionIdProvider: (() -> String?)? = nil,
//        criticalResourceGroup: DispatchGroup? = nil,
//        resourceProvider: (() -> Resource?)? = nil
//    ) {
//        self.spanProcessors = spanProcessors
//        self.spanExporters = spanExporters
//        self.embraceExporter = spanExporters.first { $0 is StorageSpanExporter } as? StorageSpanExporter
//        self.sdkStateProvider = sdkStateProvider
//        self.logger = logger
//        self.sessionIdProvider = sessionIdProvider
//        self.resourceProvider = resourceProvider
//        self.criticalResourceGroup = criticalResourceGroup
//    }
//
//    public func autoTerminateSpans() {
//        let now = Date()
//
//        let spans = _autoTerminationSpans.withLock {
//            let values = $0.values
//            $0 = [:]
//            return values
//        }
//        for data in spans {
//            data.span.setAttribute(key: SpanSemantics.keyErrorCode, value: data.code)
//            data.span.status = .error(description: data.code)
//            data.span.end(time: now)
//        }
//    }
//
//    public let isStartRequired: Bool = true
//
//    public let isEndRequired: Bool = true
//
//    public func onStart(parentContext: SpanContext?, span: OpenTelemetrySdk.ReadableSpan) {
//        guard sdkStateProvider?.isEnabled == true else {
//            return
//        }
//
//        // processors
//        let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "process-start")
//        processSpan(span)
//
//        processorQueue.async { [self] in
//            criticalResourceGroup?.wait()
//            for processor in spanProcessors {
//                processor.onStart(parentContext: parentContext, span: span)
//            }
//            mkProcessSpan.end()
//        }
//
//        // exporters
//        let mkExportSpan = EmbraceMetricKitSpan.begin(name: "export-start")
//        let data = span.toSpanData()
//        processIncompletedSpanData(data, span: span, sync: false) {
//            mkExportSpan.end()
//        }
//    }
//
//    public func onEnd(span: OpenTelemetrySdk.ReadableSpan) {
//        guard sdkStateProvider?.isEnabled == true else {
//            return
//        }
//
//        // processors
//        let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "process-end")
//        processorQueue.async { [self] in
//            criticalResourceGroup?.wait()
//            for var processor in spanProcessors {
//                processor.onEnd(span: span)
//            }
//            mkProcessSpan.end()
//        }
//
//        // exporters
//        let mkExportSpan = EmbraceMetricKitSpan.begin(name: "export-end")
//        let data = span.toSpanData()
//        processCompletedSpanData(data) {
//            mkExportSpan.end()
//        }
//    }
//
//    public func flush(span: OpenTelemetrySdk.ReadableSpan) {
//        guard sdkStateProvider?.isEnabled == true else {
//            return
//        }
//
//        // exporters
//        let mkSpan = EmbraceMetricKitSpan.begin(name: "export-flush")
//        let data = span.toSpanData()
//        processIncompletedSpanData(data, span: span, sync: true) {
//            mkSpan.end()
//        }
//    }
//
//    public func forceFlush(timeout: TimeInterval?) {
//        guard sdkStateProvider?.isEnabled == true else {
//            return
//        }
//
//        // processors
//        let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "process-forceflush")
//        let processors = self.spanProcessors
//        processorQueue.sync {
//            for processor in processors {
//                processor.forceFlush(timeout: timeout)
//            }
//            mkProcessSpan.end()
//        }
//
//        // exporters
//        let mkSpan = EmbraceMetricKitSpan.begin(name: "export-forceflush")
//        let exporters = self.spanExporters
//        processorQueue.sync {
//            for exporter in exporters {
//                _ = exporter.flush(explicitTimeout: timeout)
//            }
//            mkSpan.end()
//        }
//    }
//
//    public func shutdown(explicitTimeout: TimeInterval?) {
//
//        let processors = spanProcessors
//        let exporters = spanExporters
//
//        processorQueue.sync {
//            for var processor in processors {
//                processor.shutdown(explicitTimeout: explicitTimeout)
//            }
//
//            for exporter in exporters {
//                exporter.shutdown(explicitTimeout: explicitTimeout)
//            }
//        }
//    }
//
//    func processSpan(_ span: ReadableSpan) {
//
//        // sanitize name
//        span.name = sanitizedName(span.name, type: span.embType)
//
//        // add session id attribute
//        if let sessionId = sessionIdProvider?() {
//            span.setAttribute(key: SpanSemantics.keySessionId, value: .string(sessionId))
//        }
//    }
//
//    internal func processIncompletedSpanData(_ data: SpanData, span: ReadableSpan?, sync: Bool, completion: (() -> Void)? = nil) {
//
//        // cache if flagged for auto termination
//        _autoTerminationSpans.withLock {
//            if let span, let code = locked_autoTerminationCode(for: data, parentId: data.parentSpanId, from: &$0) {
//                $0[data.spanId] = SpanAutoTerminationData(
//                    span: span,
//                    spanData: data,
//                    code: code,
//                    parentId: data.parentSpanId
//                )
//            }
//        }
//
//        runExporters(data, sync: sync, completion: completion)
//    }
//
//    internal func processCompletedSpanData(_ spanData: SpanData, sync: Bool = false, completion: (() -> Void)? = nil) {
//        var data = spanData
//        if data.hasEnded && data.status == .unset {
//            if let errorCode = data.errorCode {
//                data.settingStatus(.error(description: String(errorCode.rawValue)))
//            } else {
//                data.settingStatus(.ok)
//            }
//        }
//
//        runExporters(data, sync: sync, completion: completion)
//    }
//
//    private func runExporters(_ span: SpanData, sync: Bool, completion: (() -> Void)? = nil) {
//        runExporters([span], sync: sync, completion: completion)
//    }
//
//    private func hydrateSpan(_ span: SpanData, with resource: Resource?) -> SpanData? {
//
//        // spanData endTime is non-optional and will be set during `toSpanData()`
//        let endTime = span.hasEnded ? span.endTime : nil
//
//        // Prevent exporting our session spans on end.
//        // This process is handled by the `SessionController` to prevent
//        // race conditions when a session ends and its payload gets built.
//        if endTime != nil && span.embType == EmbraceType.session {
//            return nil
//        }
//
//        // Prevent exporting if the name is empty
//        guard !span.name.isEmpty else {
//            logger?.warning("Can't export span with empty name!")
//            return nil
//        }
//
//        var spanData = span
//
//        // add resource
//        if let resource {
//            spanData = spanData.settingResource(resource)
//        }
//
//        return spanData
//    }
//
//    private func runExporters(_ spans: [SpanData], sync: Bool, completion: (() -> Void)? = nil) {
//
//        let exporters = self.spanExporters
//        let spansToExport: [SpanData] = spans
//        let provider = resourceProvider
//
//        let block = { [exporters, spansToExport, completion, provider, self] in
//            let resource = provider?()
//            let filteredSpans = spansToExport.compactMap { hydrateSpan($0, with: resource) }
//            for exporter in exporters {
//                _ = exporter.export(spans: filteredSpans)
//            }
//            completion?()
//        }
//
//        if sync {
//            processorQueue.sync {
//                block()
//            }
//        } else {
//            processorQueue.async { [self] in
//                criticalResourceGroup?.wait()
//                block()
//            }
//        }
//    }
//
//    // finds the auto termination code from the span's attributes
//    // also tries to find it from it's parent spans
//    private func locked_autoTerminationCode(for data: SpanData, parentId: SpanId? = nil, from: inout [SpanId: SpanAutoTerminationData]) -> String? {
//        if let code = data.attributes[SpanSemantics.keyAutoTerminationCode] {
//            return code.description
//        }
//
//        if let parentId = parentId, let parentData = from[parentId] {
//            return locked_autoTerminationCode(for: parentData.spanData, parentId: parentData.parentId, from: &from)
//        }
//        return nil
//    }
//
//    func sanitizedName(_ name: String, type: EmbraceType) -> String {
//
//        // do not truncate specific types
//        guard type != .networkRequest,
//            type != .view,
//            type != .viewLoad
//        else {
//            return name
//        }
//
//        var result = name
//
//        // trim white spaces
//        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
//        result = name.trimmingCharacters(in: trimSet)
//
//        // truncate
//        if result.count > nameLengthLimit {
//            result = String(result.prefix(nameLengthLimit))
//            logger?.warning("Span name is too long and has to be truncated!: \(name)")
//        }
//
//        return result
//    }
//}
//
//struct SpanAutoTerminationData {
//    let span: ReadableSpan
//    let spanData: SpanData
//    let code: String
//    let parentId: SpanId?
//
//    init(span: ReadableSpan, spanData: SpanData, code: String, parentId: SpanId? = nil) {
//        self.span = span
//        self.spanData = spanData
//        self.code = code
//        self.parentId = parentId
//    }
//}
