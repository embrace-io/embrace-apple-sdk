//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage
import EmbraceOTel
import OpenTelemetryApi

struct SessionSpanUtils {
    static let spanName = "emb-session"
    static let sessionIdAttribute = "emb.session_id"

    static func span(id: SessionIdentifier, startTime: Date) -> Span {
        EmbraceOTel().buildSpan(name: spanName, type: .session)
            .setStartTime(time: startTime)
            .setAttribute(key: sessionIdAttribute, value: id.toString)
            .startSpan()
    }

    static func payload(from session: SessionRecord) -> SpanPayload {
        return SpanPayload(from: session)
    }
}

fileprivate extension SpanPayload {
    init(from session: SessionRecord) {
        self.traceId = session.traceId
        self.spanId = session.spanId
        self.parentSpanId = nil
        self.name = SessionSpanUtils.spanName
        self.status = Status.ok.name
        self.startTime = session.startTime.nanosecondsSince1970Truncated
        self.endTime = session.endTime?.nanosecondsSince1970Truncated ??
                       session.lastHeartbeatTime.nanosecondsSince1970Truncated
        self.attributes = [
            SessionSpanUtils.sessionIdAttribute: session.id.toString
        ]
        self.events = []
        self.links = []
    }
}
