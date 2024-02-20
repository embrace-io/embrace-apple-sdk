//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct LogPayload: Codable {
    var timeUnixNano: String
    var severityNumber: Int
    var severityText: String
    var body = [String: String]()
    var attributes = [String: String]()
    var traceId: String?
    var spanId: String?

    enum CodingKeys: String, CodingKey {
        case timeUnixNano = "time_unix_nano"
        case severityNumber = "severity_number"
        case severityText = "severity_text"
        case traceId = "trace_id"
        case spanId = "span_id"
    }
}
