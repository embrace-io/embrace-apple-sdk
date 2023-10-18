import EmbraceOTel

extension EmbraceSpanProcessor where Self == NoopSpanProcessor {
    static var noop: NoopSpanProcessor { .init() }
}

public struct NoopSpanProcessor: EmbraceSpanProcessor {

    public init() {}

    public func onStart(span: ExportableSpan) { }

    public func onEnd(span: ExportableSpan) { }

    public func shutdown() { }
}
