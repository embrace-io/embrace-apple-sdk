//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

public protocol EmbraceOpenTelemetry: AnyObject {
    func buildSpan(
        name: String,
        type: EmbraceType,
        attributes: [String: String],
        autoTerminationCode: EmbraceSpanErrorCode?
    ) -> SpanBuilder

    func recordCompletedSpan(
        name: String,
        type: EmbraceType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: EmbraceSpanErrorCode?
    )

    func add(events: [SpanEvent])

    func add(event: SpanEvent)

    func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )

    func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )

    func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: Data,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )

    func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachmentId: String,
        attachmentUrl: URL,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )
}
