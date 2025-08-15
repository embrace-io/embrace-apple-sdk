//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

struct SpanLinkPayload: Encodable {
    let traceId: String
    let spanId: String
    let attributes: [Attribute]

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spanId = "span_id"
        case attributes
    }

    init(from link: EmbraceSpanLink) {
        self.traceId = link.context.traceId
        self.spanId = link.context.spanId

        self.attributes = link.attributes.map { entry in
            Attribute(key: entry.key, value: entry.value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(traceId, forKey: .traceId)
        try container.encode(spanId, forKey: .spanId)
        try container.encode(attributes, forKey: .attributes)
    }
}

extension SpanLinkPayload: Equatable {
    public static func == (lhs: SpanLinkPayload, rhs: SpanLinkPayload) -> Bool {
        return
            lhs.traceId == rhs.traceId && lhs.spanId == rhs.spanId
    }
}
