//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceOTelInternal
import OpenTelemetryApi

struct SessionSpanUtils {
    static let spanName = "emb-session"
    static let spanType = "ux.session"

    enum AttributeKey: String {
        case type = "emb.type"
        case id = "emb.session_id"
        case state = "emb.state"
        case coldStart = "emb.cold_start"
        case terminated = "emb.terminated"
        case cleanExit = "emb.clean_exit"
        case sessionNumber = "emb.session_number"
        case heartbeat = "emb.heartbeat_time_unix_nano"
        case crashId = "emb.crash_id"
    }

    static func span(id: SessionIdentifier, startTime: Date, state: SessionState, coldStart: Bool) -> Span {
        EmbraceOTel().buildSpan(name: spanName, type: .session)
            .setStartTime(time: startTime)
            .setAttribute(key: AttributeKey.id.rawValue, value: id.toString)
            .setAttribute(key: AttributeKey.state.rawValue, value: state.rawValue)
            .setAttribute(key: AttributeKey.coldStart.rawValue, value: coldStart)
            .startSpan()
    }

    static func setState(span: Span?, state: SessionState) {
        span?.setAttribute(key: AttributeKey.state.rawValue, value: state.rawValue)
    }

    static func setHeartbeat(span: Span?, heartbeat: Date) {
        span?.setAttribute(key: AttributeKey.heartbeat.rawValue, value: heartbeat.nanosecondsSince1970Truncated)
    }

    static func setTerminated(span: Span?, terminated: Bool) {
        span?.setAttribute(key: AttributeKey.terminated.rawValue, value: terminated)
    }

    static func setCleanExit(span: Span?, cleanExit: Bool) {
        span?.setAttribute(key: AttributeKey.cleanExit.rawValue, value: cleanExit)
    }

    static func payload(
        from session: SessionRecord,
        spanData: SpanData? = nil,
        properties: [MetadataRecord] = [],
        sessionNumber: Int
    ) -> SpanPayload {
        return SpanPayload(from: session, spanData: spanData, properties: properties, sessionNumber: sessionNumber)
    }
}

fileprivate extension SpanPayload {
    init(
        from session: SessionRecord,
        spanData: SpanData? = nil,
        properties: [MetadataRecord],
        sessionNumber: Int
    ) {
        self.traceId = session.traceId
        self.spanId = session.spanId
        self.parentSpanId = nil
        self.name = SessionSpanUtils.spanName
        self.status = Status.ok.name
        self.startTime = session.startTime.nanosecondsSince1970Truncated
        self.endTime = session.endTime?.nanosecondsSince1970Truncated ??
                       session.lastHeartbeatTime.nanosecondsSince1970Truncated

        var attributeArray: [Attribute] = [
            Attribute(
                key: SessionSpanUtils.AttributeKey.type.rawValue,
                value: SessionSpanUtils.spanType
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.id.rawValue,
                value: session.id.toString
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.state.rawValue,
                value: session.state
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.coldStart.rawValue,
                value: String(session.coldStart)
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.terminated.rawValue,
                value: String(session.appTerminated)
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.cleanExit.rawValue,
                value: String(session.cleanExit)
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.heartbeat.rawValue,
                value: String(session.lastHeartbeatTime.nanosecondsSince1970Truncated)
            ),
            Attribute(
                key: SessionSpanUtils.AttributeKey.sessionNumber.rawValue,
                value: String(sessionNumber)
            )
        ]

        if let crashId = session.crashReportId {
            attributeArray.append(Attribute(
                key: SessionSpanUtils.AttributeKey.crashId.rawValue,
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

        self.attributes = attributeArray

        if let spanData = spanData {
            self.events = spanData.events.map { SpanEventPayload(from: $0) }
            self.links = spanData.links.map { SpanLinkPayload(from: $0) }
        } else {
            self.events = []
            self.links = []
        }
    }
}
