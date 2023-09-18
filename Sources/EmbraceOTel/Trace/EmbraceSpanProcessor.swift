import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// A really simple implementation of the SpanProcessor that converts the ReadableSpan SpanData
/// and passes it to the configured exporter in both `onStart` and `onEnd`
public struct EmbraceSpanProcessor: SpanProcessor {
    private let spanExporter: SpanExporter
    private let processorQueue = DispatchQueue(label: "io.embrace.spanprocessor", qos: .utility)

    public let isStartRequired = true
    public let isEndRequired = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        let span = span.toSpanData()
        let exporter = self.spanExporter
        processorQueue.async {
            // TODO: Do we need to call a different method to specify the "start" of the span?
            exporter.export(spans: [span])
        }
    }

    public mutating func onEnd(span: ReadableSpan) {
        let span = span.toSpanData()
        let exporter = self.spanExporter
        processorQueue.async {
            exporter.export(spans: [span])
        }
    }

    public func shutdown() {
        processorQueue.sync {
            spanExporter.shutdown()
        }
    }

    /// Forces the processing of the remaining spans
    /// - Parameter timeout: unused in this processor
    public func forceFlush(timeout: TimeInterval? = nil) {
        processorQueue.sync {
            _ = spanExporter.flush()
        }
    }

    /// Returns a new SimpleSpansProcessor that converts spans to proto and forwards them to
    /// the given spanExporter.
    /// - Parameter spanExporter: the SpanExporter to where the Spans are pushed.
    public init(spanExporter: SpanExporter) {
        self.spanExporter = spanExporter
    }

}
