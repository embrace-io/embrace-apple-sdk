//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal

struct SpanEventPayload: Encodable {
    let name: String
    let timestamp: Int
    let attributes: [Attribute]

    enum CodingKeys: String, CodingKey {
        case name
        case timestamp = "time_unix_nano"
        case attributes
    }

    init(from event: SpanEvent) {
        self.name = event.name
        self.timestamp = event.timestamp.nanosecondsSince1970Truncated
        self.attributes = PayloadUtils.convertSpanAttributes(event.attributes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(attributes, forKey: .attributes)
    }
}

extension SpanEventPayload: Equatable {
    public static func == (lhs: SpanEventPayload, rhs: SpanEventPayload) -> Bool {
        return
            lhs.name == rhs.name &&
            lhs.timestamp == rhs.timestamp
    }
}
