//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

public struct LogRecord: Codable {
    /*
     Check if we'd need here:
     - Attributes (either user provided + resources or the ones provided alone)
     - TraceId
     - SpanId
     */
    public var id: LogIdentifier
    public var timestamp: Date
    public var severity: LogSeverity
    public var body: String

    enum CodingKeys: CodingKey {
        case id
        case timestamp
        case body
        case severity
    }

    public init(
        id: LogIdentifier,
        timestamp: Date = Date(),
        severity: LogSeverity,
        body: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.body = body
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(severity, forKey: .severity)
        try container.encode(body, forKey: .body)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(LogIdentifier.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.severity = try container.decode(LogSeverity.self, forKey: .severity)
        self.body = try container.decode(String.self, forKey: .body)
    }
}
