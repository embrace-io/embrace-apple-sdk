//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class MockSpanProcessor: SpanProcessor {

    // Appended from background queues while tests read them on the main thread — see `TestLocked`.
    @TestLocked public private(set) var startedSpans = [SpanData]()
    @TestLocked public private(set) var endedSpans = [SpanData]()
    @TestLocked public private(set) var didShutdown = false
    @TestLocked public private(set) var didForceFlush = false

    private var _onStartCallback: ((ReadableSpan) -> Void)?
    /// Called synchronously from `onStart`, outside of the processor's own lock.
    public var onStartCallback: ((ReadableSpan) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onStartCallback
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onStartCallback = newValue
        }
    }

    private var _onEndCallback: ((ReadableSpan) -> Void)?
    /// Called synchronously from `onEnd`, outside of the processor's own lock.
    public var onEndCallback: ((ReadableSpan) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onEndCallback
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onEndCallback = newValue
        }
    }

    public init() {}

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        onStartCallback?(span)

        let data = span.toSpanData()
        lock.lock()
        defer { lock.unlock() }
        _startedSpans.append(data)
    }

    public func onEnd(span: ReadableSpan) {
        onEndCallback?(span)

        let data = span.toSpanData()
        lock.lock()
        defer { lock.unlock() }
        _endedSpans.append(data)
    }

    public func forceFlush(timeout: TimeInterval?) {
        didForceFlush = true
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }

}
