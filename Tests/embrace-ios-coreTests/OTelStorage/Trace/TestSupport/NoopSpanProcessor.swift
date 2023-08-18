import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct NoopSpanProcessor: SpanProcessor {
    init() {}

    let isStartRequired = false
    let isEndRequired = false

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {}

    func shutdown() {}

    func forceFlush(timeout: TimeInterval? = nil) {}
}
