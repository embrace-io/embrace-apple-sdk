//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

public struct RecordingSpanEvent: SpanEvent, Codable, Equatable {
    public let name: String
    public let timestamp: Date
    public let attributes: [String: AttributeValue]
}

public func == (lhs: RecordingSpanEvent, rhs: RecordingSpanEvent) -> Bool {
    return lhs.name == rhs.name &&
        lhs.timestamp == rhs.timestamp &&
        lhs.attributes == rhs.attributes
}

public func == (lhs: [RecordingSpanEvent], rhs: [RecordingSpanEvent]) -> Bool {
    return lhs.elementsEqual(rhs) { $0 == $1 }
}
