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

    /// Called synchronously from `onStart`, before the span is recorded.
    @TestLocked public var onStartCallback: ((ReadableSpan) -> Void)?
    /// Called synchronously from `onEnd`, before the span is recorded.
    @TestLocked public var onEndCallback: ((ReadableSpan) -> Void)?

    public init() {}

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        onStartCallback?(span)

        startedSpans.append(span.toSpanData())
    }

    public func onEnd(span: ReadableSpan) {
        onEndCallback?(span)

        endedSpans.append(span.toSpanData())
    }

    public func forceFlush(timeout: TimeInterval?) {
        didForceFlush = true
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }

}
