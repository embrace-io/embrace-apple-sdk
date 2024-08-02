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
        type: LogType,
        severity: LogSeverity,
        type: LogType,
        attributes: [String: String]
    )

    func log(
        _ message: String,
        type: LogType,
        severity: LogSeverity,
        type: LogType,
        timestamp: Date,
        attributes: [String: String]
    )
}

extension EmbraceOpenTelemetry {
    public func log(
        _ message: String,
        type: LogType = .default,
        severity: LogSeverity,
        attributes: [String: String]
    ) {
        log(message, type: type, severity: severity, attributes: attributes)
    }

    public func log(
        _ message: String,
        type: LogType = .default,
        severity: LogSeverity,
        timestamp: Date,
        attributes: [String: String]
    ) {
        log(message, type: type, severity: severity, timestamp: timestamp, attributes: attributes)
    }
}
