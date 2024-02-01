//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

struct SpanPayload: Encodable {
    let traceId: String
    let spanId: String
    let parentSpanId: String?
    let name: String
    let status: String
    let startTime: Int
    let endTime: Int?
    let attributes: [String: Any]
    let events: [SpanEventPayload]
    let links: [SpanLinkPayload]

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spanId = "span_id"
        case parentSpanId = "parent_span_id"
        case name
        case status
        case startTime = "start_time_unix_nano"
        case endTime = "end_time_unix_nano"
        case attributes
        case events
        case links
    }

    init(from span: SpanData, endTime: Date? = nil) {
        self.traceId = span.traceId.hexString
        self.spanId = span.spanId.hexString
        self.parentSpanId = span.parentSpanId?.hexString
        self.name = span.name
        self.status = span.status.name
        self.startTime = span.startTime.nanosecondsSince1970Truncated
        self.endTime = (endTime ?? span.endTime)?.nanosecondsSince1970Truncated
        self.attributes = PayloadUtils.convertSpanAttributes(span.attributes)
        self.events = span.events.map { SpanEventPayload(from: $0) }
        self.links = span.links.map { SpanLinkPayload(from: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(traceId, forKey: .traceId)
        try container.encode(spanId, forKey: .spanId)
        try container.encodeIfPresent(parentSpanId, forKey: .parentSpanId)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(events, forKey: .events)
        try container.encode(links, forKey: .links)
    }
}

extension SpanPayload: Equatable {
    public static func == (lhs: SpanPayload, rhs: SpanPayload) -> Bool {
        return
            lhs.traceId == rhs.traceId &&
            lhs.spanId == rhs.spanId &&
            lhs.parentSpanId == rhs.parentSpanId &&
            lhs.name == rhs.name &&
            lhs.status == rhs.status &&
            lhs.endTime == rhs.endTime &&
            lhs.startTime == rhs.startTime &&
            lhs.events == rhs.events &&
            lhs.links == rhs.links
    }
}
