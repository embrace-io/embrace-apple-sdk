import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct NoopSpanProcessor: SpanProcessor {
    public init() {}

    public let isStartRequired = false
    public let isEndRequired = false

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

    public func onEnd(span: ReadableSpan) {}

    public func shutdown() {}

    public func forceFlush(timeout: TimeInterval? = nil) {}
}
