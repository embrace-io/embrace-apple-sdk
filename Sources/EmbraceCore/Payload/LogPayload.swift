//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

struct LogPayload: Codable {
    var timeUnixNano: String
    var severityNumber: Int
    var severityText: String
    var body: String
    var attributes: [Attribute]
    var traceId: String?
    var spanId: String?

    enum CodingKeys: String, CodingKey {
        case timeUnixNano = "time_unix_nano"
        case severityNumber = "severity_number"
        case severityText = "severity_text"
        case body = "body"
        case attributes = "attributes"
        case traceId = "trace_id"
        case spanId = "span_id"
    }
}
