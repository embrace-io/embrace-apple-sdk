import Foundation
import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk

extension SpanProcessor where Self == NoopSpanProcessor {
    static var noop: NoopSpanProcessor { .init() }
}

public struct NoopSpanProcessor: SpanProcessor {
    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) { }

    public mutating func onEnd(span: ReadableSpan) { }

    public func forceFlush(timeout: TimeInterval?) { }

    public mutating func shutdown(explicitTimeout: TimeInterval?) { }
}
