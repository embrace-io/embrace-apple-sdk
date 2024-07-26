//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// A really simple implementation of the SpanProcessor that converts the ExportableSpan to SpanData
/// and passes it to the configured exporter in both `onStart` and `onEnd`
public struct SingleSpanProcessor: EmbraceSpanProcessor {

    let spanExporter: SpanExporter
    private let processorQueue = DispatchQueue(label: "io.embrace.spanprocessor", qos: .utility)

    /// Returns a new SingleSpanProcessor that converts spans to SpanData and forwards them to
    /// the given spanExporter.
    /// - Parameter spanExporter: the SpanExporter to where the Spans are pushed.
    public init(spanExporter: SpanExporter) {
        self.spanExporter = spanExporter
    }

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: OpenTelemetrySdk.ReadableSpan) {
        let exporter = self.spanExporter

        let data = span.toSpanData()

        processorQueue.async {
            exporter.export(spans: [data])
        }
    }

    public func onEnd(span: OpenTelemetrySdk.ReadableSpan) {
        let exporter = self.spanExporter

        var data = span.toSpanData()
        if data.hasEnded && data.status == .unset {
            if let errorCode = data.errorCode {
                data.settingStatus(.error(description: errorCode.rawValue))
            } else {
                data.settingStatus(.ok)
            }
        }

        processorQueue.async {
            exporter.export(spans: [data])
        }
    }

    public func forceFlush(timeout: TimeInterval?) {
        _ = processorQueue.sync { spanExporter.flush() }
    }

    public func shutdown() {
        processorQueue.sync {
            spanExporter.shutdown()
        }
    }

}
