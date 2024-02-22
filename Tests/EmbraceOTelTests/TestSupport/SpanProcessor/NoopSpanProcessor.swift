import Foundation
import EmbraceOTel

extension EmbraceSpanProcessor where Self == NoopSpanProcessor {
    static var noop: NoopSpanProcessor { .init() }
}

public struct NoopSpanProcessor: EmbraceSpanProcessor {
    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) { }

    public mutating func onEnd(span: ReadableSpan) { }

    public func forceFlush(timeout: TimeInterval?) { }

    public mutating func shutdown() { }
}
