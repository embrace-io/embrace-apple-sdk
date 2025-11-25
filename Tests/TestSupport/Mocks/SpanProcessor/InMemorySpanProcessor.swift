//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class InMemorySpanProcessor: SpanProcessor {

    public var isStartRequired: Bool
    public var isEndRequired: Bool

    public private(set) var startedSpans: [SpanId: SpanData] = [:]
    public private(set) var endedSpans: [SpanId: SpanData] = [:]
    public private(set) var isShutdown: Bool = false

    private var onFlush: (() -> Void)? = nil

    public convenience init() {
        self.init(isStartRequired: false, isEndRequired: false)
    }

    public init(isStartRequired: Bool, isEndRequired: Bool) {
        self.isStartRequired = isStartRequired
        self.isEndRequired = isEndRequired
    }

    public func onFlush(completion: (() -> Void)?) {
        self.onFlush = completion
    }

    public func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        let data = span.toSpanData()
        startedSpans[data.spanId] = data
    }

    public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
        let data = span.toSpanData()
        endedSpans[data.spanId] = data
    }

    public func forceFlush(timeout: TimeInterval?) {
        onFlush?()
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        isShutdown = true
    }
}
