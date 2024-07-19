//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

extension SpanRecord {
    /// Build QueryInterfaceRequest for SpanRecord that will query for:
    /// ```swift
    /// if session.coldStart
    ///    // spans that occur within same process that start before the session endTime
    /// else
    ///    // spans that overlap with session start/end times
    /// ```
    ///
    /// Parameters:
    ///    - session: The session record to use as context when querying for spans
    static func filter(for session: SessionRecord) -> QueryInterfaceRequest<Self> {
        let sessionEndTime = session.endTime ?? session.lastHeartbeatTime

        if session.coldStart {
            return SpanRecord.filter(
                // same process and starts before session ends
                SpanRecord.Schema.processIdentifier == session.processId &&
                SpanRecord.Schema.startTime <= sessionEndTime )

        } else {
            return SpanRecord.filter(
                overlappingStart(startTime: session.startTime) ||
                entirelyWithin(startTime: session.startTime, endTime: sessionEndTime) ||
                overlappingEnd(endTime: sessionEndTime) ||
                entirelyOverlapped(startTime: session.startTime, endTime: sessionEndTime)
            )
        }
    }

    /// Where `Span.startTime` occurs before session start and `Span.endTime` occurs after session start or has not ended
    private static func overlappingStart(startTime: Date) -> SQLExpression {
        SpanRecord.Schema.startTime <= startTime &&
        SpanRecord.Schema.endTime >= startTime
    }

    /// Where both `Span.startTime` and `Span.endTime` occur after session start and before session end
    private static func entirelyWithin(startTime: Date, endTime: Date) -> SQLExpression {
        SpanRecord.Schema.startTime >= startTime &&
        (SpanRecord.Schema.endTime <= endTime || SpanRecord.Schema.endTime == nil)
    }

    /// Where `Span.startTime` occurs before session end and `Span.endTime` occurs after session end or has not ended
    private static func overlappingEnd(endTime: Date) -> SQLExpression {
        SpanRecord.Schema.startTime <= endTime &&
        (SpanRecord.Schema.endTime >= endTime || SpanRecord.Schema.endTime == nil)
    }

    /// Where `Span.startTime` occurs before session start and `Span.endTime` occurs after session end or Span has not ended
    private static func entirelyOverlapped(startTime: Date, endTime: Date) -> SQLExpression {
        SpanRecord.Schema.startTime <= startTime &&
        (SpanRecord.Schema.endTime >= endTime || SpanRecord.Schema.endTime == nil)
    }
}
