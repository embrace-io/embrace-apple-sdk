//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceSemantics
#endif

struct SessionSpanUtils {

    static func span(
        otel: EmbraceOTelSignalsHandler?,
        id: EmbraceIdentifier,
        startTime: Date,
        state: SessionState,
        coldStart: Bool
    ) -> EmbraceSpan? {

        // Note: `session.id` (== user-session UUID in v7) and `emb.user_session_id` are NOT
        // stamped here — the user-session controller's `attachPart` runs after the span is
        // created in `SessionController.startSession`, so those values aren't known yet.
        // `SessionSpanUtils.payload` (the wire-format builder) emits them at upload time when
        // the part record's `userSessionId` column is populated.
        let attributes: [String: String] = [
            SpanSemantics.Session.keyPartId: id.stringValue,
            SpanSemantics.Session.keyState: state.rawValue,
            SpanSemantics.Session.keyColdStart: String(coldStart)
        ]

        return try? otel?.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: startTime,
            attributes: attributes
        )
    }

    static func setState(span: EmbraceSpan?, state: SessionState) {
        span?.setInternalAttribute(key: SpanSemantics.Session.keyState, value: state.rawValue)
    }

    static func setHeartbeat(span: EmbraceSpan?, heartbeat: Date) {
        span?.setInternalAttribute(key: SpanSemantics.Session.keyHeartbeat, value: String(heartbeat.nanosecondsSince1970Truncated))
    }

    static func setTerminated(span: EmbraceSpan?, terminated: Bool) {
        span?.setInternalAttribute(key: SpanSemantics.Session.keyTerminated, value: String(terminated))
    }

    static func payload(
        from session: EmbraceSession,
        span: EmbraceSpan? = nil,
        properties: [EmbraceMetadata] = []
    ) -> SpanPayload {
        return SpanPayload(from: session, span: span, properties: properties)
    }
}

extension SpanPayload {
    fileprivate init(
        from session: EmbraceSession,
        span: EmbraceSpan? = nil,
        properties: [EmbraceMetadata]
    ) {
        self.traceId = session.traceId
        self.spanId = session.spanId
        self.parentSpanId = nil
        self.name = SpanSemantics.Session.name
        self.status = session.crashReportId != nil ? EmbraceSpanStatus.error.name : EmbraceSpanStatus.ok.name
        self.startTime = session.startTime.nanosecondsSince1970Truncated
        self.endTime =
            session.endTime?.nanosecondsSince1970Truncated ?? session.lastHeartbeatTime.nanosecondsSince1970Truncated

        let userSessionIdValue = session.userSessionId?.stringValue ?? ""

        var attributeArray: [Attribute] = [
            Attribute(key: SpanSemantics.keyEmbraceType, value: EmbraceType.session.rawValue),

            // Identity. The backend uses the presence of `emb.session_part_id` to detect new
            // SDKs, so all three keys are always emitted — empty strings when unknown (pre-v7
            // legacy rows still in storage at upgrade time).
            Attribute(key: SpanSemantics.Session.keyId, value: userSessionIdValue),
            Attribute(key: SpanSemantics.Session.keyUserSessionId, value: userSessionIdValue),
            Attribute(key: SpanSemantics.Session.keyPartId, value: session.id.stringValue),

            // State
            Attribute(key: SpanSemantics.Session.keyState, value: session.state.rawValue),
            Attribute(key: SpanSemantics.Session.keyColdStart, value: String(session.coldStart)),
            Attribute(key: SpanSemantics.Session.keyTerminated, value: String(session.appTerminated)),
            Attribute(key: SpanSemantics.Session.keyCleanExit, value: String(session.cleanExit)),
            Attribute(
                key: SpanSemantics.Session.keyHeartbeat,
                value: String(session.lastHeartbeatTime.nanosecondsSince1970Truncated)
            ),

            // Counters
            Attribute(
                key: SpanSemantics.Session.keySessionPartNumber,
                value: String(session.sessionNumber)
            ),
            Attribute(
                key: SpanSemantics.Session.keyUserSessionPartIndex,
                value: String(session.userSessionPartIndex)
            ),

            // User-session config snapshots — read from the part record, which captured them
            // when the user session was created. Pre-v7 rows return nil/0; emit defaults.
            Attribute(
                key: SpanSemantics.Session.keyUserSessionStartTs,
                value: String((session.userSessionStartTime ?? session.startTime).nanosecondsSince1970Truncated)
            ),
            Attribute(
                key: SpanSemantics.Session.keyUserSessionMaxDurationSeconds,
                value: String(Int(session.userSessionMaxDuration ?? 0))
            ),
            Attribute(
                key: SpanSemantics.Session.keyUserSessionInactivityTimeoutSeconds,
                value: String(session.userSessionInactivityTimeout ?? 0)
            )
        ]

        if let crashId = session.crashReportId {
            attributeArray.append(Attribute(key: SpanSemantics.Session.keyCrashId, value: crashId))
        }

        // Termination reason and final-part flag travel together — both emitted only on the
        // last part of a terminated user session. `emb.is_final_session_part` is `"1"` when
        // set, otherwise the key is omitted entirely.
        if let terminationReason = session.userSessionTerminationReason {
            attributeArray.append(
                Attribute(
                    key: SpanSemantics.Session.keyUserSessionTerminationReason,
                    value: terminationReason.rawValue
                )
            )
            attributeArray.append(
                Attribute(key: SpanSemantics.Session.keyIsFinalSessionPart, value: "1")
            )
        }

        attributeArray.append(
            contentsOf: properties.compactMap { record in
                guard !record.key.starts(with: "emb.user") else {
                    return nil
                }
                return Attribute(
                    key: String(format: "emb.properties.%@", record.key),
                    value: record.value.description
                )
            }
        )

        self.events = span?.events.map { SpanEventPayload(from: $0) } ?? []
        self.links = span?.links.map { SpanLinkPayload(from: $0) } ?? []
        self.attributes = attributeArray
    }
}
