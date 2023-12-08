//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTel

struct SpanLinkPayload: Encodable {
    let traceId: String
    let spanId: String
    let attributes: [String: Any]

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spanId = "span_id"
        case attributes
    }

    init(from link: RecordingSpanLink) {
        self.traceId = link.traceId.hexString
        self.spanId = link.spanId.hexString
        self.attributes = PayloadUtils.convertSpanAttributes(link.attributes)
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
            lhs.traceId == rhs.traceId &&
            lhs.spanId == rhs.spanId
    }
}
