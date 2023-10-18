//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

public struct RecordingSpanLink: Codable, Equatable {
    public let context: SpanContext
    public let attributes: [String: AttributeValue]

    init(context: SpanContext, attributes: [String: AttributeValue] = [:]) {
        self.context = context
        self.attributes = attributes
    }
}

public func == (lhs: RecordingSpanLink, rhs: RecordingSpanLink) -> Bool {
    return lhs.context == rhs.context && lhs.attributes == rhs.attributes
}

public func == (lhs: [RecordingSpanLink], rhs: [RecordingSpanLink]) -> Bool {
    return lhs.elementsEqual(rhs) { $0.context == $1.context && $0.attributes == $1.attributes }
}
