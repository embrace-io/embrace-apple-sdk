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

    static func spanData(from record: SessionRecord) -> SpanData {
        // TODO: Define special attribute for "fake session span"
        return SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: spanName,
            kind: .internal,
            startTime: record.startTime,
            endTime: record.endTime,
            attributes: [sessionIdAttribute: .string(record.id.toString)]
        )
    }

    static func span(id: SessionIdentifier, startTime: Date) -> Span {
        EmbraceOTel().buildSpan(name: spanName, type: .session)
            .setStartTime(time: startTime)
            .setAttribute(key: sessionIdAttribute, value: id.toString)
            .startSpan()
    }
}
