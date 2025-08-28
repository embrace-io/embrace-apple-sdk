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
        otel: OTelSignalsHandler?,
        id: EmbraceIdentifier,
        startTime: Date,
        state: SessionState,
        coldStart: Bool
    ) -> EmbraceSpan? {

        let attributes: [String: String] = [
            SpanSemantics.Session.keyId: id.stringValue,
            SpanSemantics.Session.keyState: state.rawValue,
            SpanSemantics.Session.keyColdStart: String(coldStart)
        ]

        return try? otel?.createSpan(
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
        properties: [EmbraceMetadata] = [],
        sessionNumber: Int
    ) -> SpanPayload {
        return SpanPayload(from: session, span: span, properties: properties, sessionNumber: sessionNumber)
    }
}

extension SpanPayload {
    fileprivate init(
        from session: EmbraceSession,
        span: EmbraceSpan? = nil,
        properties: [EmbraceMetadata],
        sessionNumber: Int
    ) {
        self.traceId = session.traceId
        self.spanId = session.spanId
        self.parentSpanId = nil
        self.name = SpanSemantics.Session.name
        self.status = session.crashReportId != nil ? EmbraceSpanStatus.error.name : EmbraceSpanStatus.ok.name
        self.startTime = session.startTime.nanosecondsSince1970Truncated
        self.endTime =
            session.endTime?.nanosecondsSince1970Truncated ?? session.lastHeartbeatTime.nanosecondsSince1970Truncated

        var attributeArray: [Attribute] = [
            Attribute(
                key: SpanSemantics.keyEmbraceType,
                value: EmbraceType.session.rawValue
            ),
            Attribute(
                key: SpanSemantics.Session.keyId,
                value: session.id.stringValue
            ),
            Attribute(
                key: SpanSemantics.Session.keyState,
                value: session.state.rawValue
            ),
            Attribute(
                key: SpanSemantics.Session.keyColdStart,
                value: String(session.coldStart)
            ),
            Attribute(
                key: SpanSemantics.Session.keyTerminated,
                value: String(session.appTerminated)
            ),
            Attribute(
                key: SpanSemantics.Session.keyCleanExit,
                value: String(session.cleanExit)
            ),
            Attribute(
                key: SpanSemantics.Session.keyHeartbeat,
                value: String(session.lastHeartbeatTime.nanosecondsSince1970Truncated)
            ),
            Attribute(
                key: SpanSemantics.Session.keySessionNumber,
                value: String(sessionNumber)
            )
        ]

        if let crashId = session.crashReportId {
            attributeArray.append(
                Attribute(
                    key: SpanSemantics.Session.keyCrashId,
                    value: crashId
                ))
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
