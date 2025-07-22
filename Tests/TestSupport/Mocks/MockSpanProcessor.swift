//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class MockSpanProcessor: SpanProcessor {

    private(set) public var startedSpans = [SpanData]()
    private(set) public var endedSpans = [SpanData]()
    private(set) public var didShutdown = false
    private(set) public var didForceFlush = false

    public init() {}

    public let isStartRequired: Bool = true

    public let isEndRequired: Bool = true

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        startedSpans.append(span.toSpanData())
    }

    public func onEnd(span: ReadableSpan) {
        endedSpans.append(span.toSpanData())
    }

    public func forceFlush(timeout: TimeInterval?) {
        didForceFlush = true
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }

}
