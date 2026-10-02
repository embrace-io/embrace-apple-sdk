//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class MockSpanProcessor: SpanProcessor {

    private let lock = NSLock()

    private var _startedSpans = [SpanData]()
    public var startedSpans: [SpanData] {
        lock.lock()
        defer { lock.unlock() }
        return _startedSpans
    }

    private var _endedSpans = [SpanData]()
    public var endedSpans: [SpanData] {
        lock.lock()
        defer { lock.unlock() }
        return _endedSpans
    }

    private var _didShutdown = false
    public var didShutdown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didShutdown
    }

    private var _didForceFlush = false
    public var didForceFlush: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didForceFlush
    }

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
        lock.lock()
        defer { lock.unlock() }
        _didForceFlush = true
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        _didShutdown = true
    }

}
