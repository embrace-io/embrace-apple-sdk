//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

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

    public init() {}

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        let data = span.toSpanData()
        lock.lock()
        defer { lock.unlock() }
        _startedSpans.append(data)
    }

    public func onEnd(span: ReadableSpan) {
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
