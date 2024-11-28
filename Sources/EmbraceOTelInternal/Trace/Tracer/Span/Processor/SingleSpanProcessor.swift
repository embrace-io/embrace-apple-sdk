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

    @ThreadSafe var autoTerminationSpans: [String: ReadableSpan] = [:]

    /// Returns a new SingleSpanProcessor that converts spans to SpanData and forwards them to
    /// the given spanExporter.
    /// - Parameter spanExporter: the SpanExporter to where the Spans are pushed.
    public init(spanExporter: SpanExporter) {
        self.spanExporter = spanExporter
    }

    public func autoTerminateSpans() {
        for span in autoTerminationSpans.values {
            let data = span.toSpanData()
            guard let errorCode = data.attributes[SpanSemantics.keyAutoTerminationCode]?.description else {
                continue
            }

            span.setAttribute(key: SpanSemantics.keyErrorCode, value: errorCode)
            span.status = .error(description: errorCode)
            span.end()
        }

        autoTerminationSpans.removeAll()
    }

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: OpenTelemetrySdk.ReadableSpan) {
        let exporter = self.spanExporter

        let data = span.toSpanData()

        // cache if flagged for auto termination
        if data.attributes[SpanSemantics.keyAutoTerminationCode] != nil {
            autoTerminationSpans[span.autoTerminationKey] = span
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
        if data.attributes[SpanSemantics.keyAutoTerminationCode] != nil {
            autoTerminationSpans[span.autoTerminationKey] = span
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
}

extension Span {
    var autoTerminationKey: String {
        context.traceId.hexString + "_" + context.spanId.hexString
    }
}
