//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import EmbraceCommonInternal

public protocol EmbraceOpenTelemetry: AnyObject {
    func buildSpan(name: String,
                   type: SpanType,
                   attributes: [String: String]) -> SpanBuilder

    func recordCompletedSpan(
        name: String,
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: ErrorCode?
    )

    func add(events: [SpanEvent])

    func add(event: SpanEvent)

    func log(
        _ message: String,
        severity: LogSeverity,
        attributes: [String: String]
    )

    func log(
        _ message: String,
        severity: LogSeverity,
        timestamp: Date,
        attributes: [String: String]
    )
}
