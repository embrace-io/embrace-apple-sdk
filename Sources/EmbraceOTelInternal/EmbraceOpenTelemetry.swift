//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import EmbraceCommonInternal
import EmbraceSemantics

public protocol EmbraceOpenTelemetry: AnyObject {
    func buildSpan(name: String,
                   type: SpanType,
                   attributes: [String: String],
                   autoTerminationCode: SpanErrorCode?
    ) -> SpanBuilder

    func recordCompletedSpan(
        name: String,
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: SpanErrorCode?
    )

    func add(events: [SpanEvent])

    func add(event: SpanEvent)

    func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )

    func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
        timestamp: Date,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )

    func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
        timestamp: Date,
        attachment: Data,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )

    func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
        timestamp: Date,
        attachmentId: String,
        attachmentUrl: URL,
        attachmentSize: Int?,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )
}
