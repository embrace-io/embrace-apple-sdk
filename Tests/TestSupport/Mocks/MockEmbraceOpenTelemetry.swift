//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceOTel
@testable import EmbraceCore
import EmbraceCommon
import OpenTelemetryApi

public class MockEmbraceOpenTelemetry: EmbraceOpenTelemetry {
    private(set) public var spanProcessor = MockSpanProcessor()
    private(set) public var events: [SpanEvent] = []

    public init() {
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
    }

    public func buildSpan(
        name: String,
        type: SpanType,
        attributes: [String: String]) -> SpanBuilder {

        return EmbraceOTel()
            .buildSpan(name: name, type: type, attributes: attributes)
    }

    public func recordCompletedSpan(
        name: String,
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: ErrorCode? ) {

    }

    public func add(events: [SpanEvent]) {
        self.events.append(contentsOf: events)
    }

    public func add(event: SpanEvent) {
        events.append(event)
    }
}
