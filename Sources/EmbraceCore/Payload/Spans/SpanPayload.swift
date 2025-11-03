//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

struct SpanPayload: Encodable {
    let traceId: String
    let spanId: String
    let parentSpanId: String?
    let name: String
    let status: String
    let startTime: Int
    let endTime: Int?
    let attributes: [Attribute]
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

    init(from span: EmbraceSpan, endTime: Date? = nil, failed: Bool = false) {
        self.traceId = span.context.traceId
        self.spanId = span.context.spanId
        self.parentSpanId = span.parentSpanId
        self.name = span.name
        self.startTime = span.startTime.nanosecondsSince1970Truncated
        self.events = span.events.map { SpanEventPayload(from: $0) }
        self.links = span.links.map { SpanLinkPayload(from: $0) }

        if span.status == .ok || !failed {
            self.status = span.status.name
        } else {
            self.status = EmbraceSpanStatus.error.name
        }

        let end = endTime ?? span.endTime
        if let end {
            self.endTime = end.nanosecondsSince1970Truncated
        } else {
            self.endTime = nil
        }

        var attributeArray: [Attribute] = span.attributes.map { entry in
            Attribute(key: entry.key, value: String(describing: entry.value))
        }
        if failed {
            attributeArray.append(Attribute(key: SpanSemantics.keyErrorCode, value: "failure"))
        }
        self.attributes = attributeArray
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
            lhs.traceId == rhs.traceId && lhs.spanId == rhs.spanId && lhs.parentSpanId == rhs.parentSpanId
            && lhs.name == rhs.name && lhs.status == rhs.status && lhs.endTime == rhs.endTime
            && lhs.startTime == rhs.startTime && lhs.events == rhs.events && lhs.links == rhs.links
    }
}
