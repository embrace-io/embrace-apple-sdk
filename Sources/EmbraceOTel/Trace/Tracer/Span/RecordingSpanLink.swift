//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

public struct RecordingSpanLink: Codable, Equatable {
    public let traceId: TraceId
    public let spanId: SpanId
    public let attributes: [String: AttributeValue]

    init(traceId: TraceId, spanId: SpanId, attributes: [String: AttributeValue] = [:]) {
        self.traceId = traceId
        self.spanId = spanId
        self.attributes = attributes
    }
}

public func == (lhs: RecordingSpanLink, rhs: RecordingSpanLink) -> Bool {
    return lhs.traceId == rhs.traceId && lhs.spanId == rhs.spanId && lhs.attributes == rhs.attributes
}

public func == (lhs: [RecordingSpanLink], rhs: [RecordingSpanLink]) -> Bool {
    return lhs.elementsEqual(rhs) { $0.traceId == $1.traceId && $0.spanId == $1.spanId && $0.attributes == $1.attributes }
}
