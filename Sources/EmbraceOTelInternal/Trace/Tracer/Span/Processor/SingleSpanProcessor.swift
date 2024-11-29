//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import EmbraceSemantics
import EmbraceCommonInternal

/// A really simple implementation of the SpanProcessor that converts the ExportableSpan to SpanData
/// and passes it to the configured exporter in both `onStart` and `onEnd`
public class SingleSpanProcessor: SpanProcessor {

    let spanExporter: SpanExporter
    private let processorQueue = DispatchQueue(label: "io.embrace.spanprocessor", qos: .utility)

    @ThreadSafe var autoTerminationSpans: [SpanId: SpanAutoTerminationData] = [:]

    /// Returns a new SingleSpanProcessor that converts spans to SpanData and forwards them to
    /// the given spanExporter.
    /// - Parameter spanExporter: the SpanExporter to where the Spans are pushed.
    public init(spanExporter: SpanExporter) {
        self.spanExporter = spanExporter
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
        let exporter = self.spanExporter

        let data = span.toSpanData()

        // cache if flagged for auto termination
        if let code = autoTerminationCode(for: data, parentId: data.parentSpanId) {
            autoTerminationSpans[data.spanId] = SpanAutoTerminationData(
                span: span,
                spanData: data,
                code: code, 
                parentId: data.parentSpanId
            )
        }

        processorQueue.async {
            _ = exporter.export(spans: [data])
        }
    }

    public func onEnd(span: OpenTelemetrySdk.ReadableSpan) {
        var data = span.toSpanData()
        if data.hasEnded && data.status == .unset {
            if let errorCode = data.errorCode {
                data.settingStatus(.error(description: errorCode.rawValue))
            } else {
                data.settingStatus(.ok)
            }
        }

        processorQueue.async {
            _ = self.spanExporter.export(spans: [data])
        }
    }

    public func flush(span: OpenTelemetrySdk.ReadableSpan) {
        let data = span.toSpanData()

        // update cache if needed
        if let code = autoTerminationCode(for: data, parentId: data.parentSpanId) {
            autoTerminationSpans[data.spanId] = SpanAutoTerminationData(
                span: span,
                spanData: data,
                code: code,
                parentId: data.parentSpanId
            )
        }

        processorQueue.sync {
            _ = self.spanExporter.export(spans: [data])
        }
    }

    public func forceFlush(timeout: TimeInterval?) {
        _ = processorQueue.sync { spanExporter.flush() }
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        processorQueue.sync {
            spanExporter.shutdown()
        }
    }

    // finds the auto termination code from the span's attributes
    // also tries to find it from it's parent spans
    private func autoTerminationCode(for data: SpanData, parentId: SpanId? = nil) -> String? {
        if let code = data.attributes[SpanSemantics.keyAutoTerminationCode] {
            return code.description
        }

        if let parentId = parentId,
           let parentData = autoTerminationSpans[parentId] {
            return autoTerminationCode(for: parentData.spanData, parentId: parentData.parentId)
        }

        return nil
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
