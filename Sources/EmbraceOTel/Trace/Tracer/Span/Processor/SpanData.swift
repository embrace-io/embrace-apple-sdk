//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

/// representation of all data collected by the Span.
public struct SpanData: Equatable, Codable {
    /// The trace id for this span.
    public private(set) var traceId: TraceId

    /// The span id for this span.
    public private(set) var spanId: SpanId

    /// The parent SpanId. If the  Span is a root Span, the SpanId
    /// returned will be nil.
    public private(set) var parentSpanId: SpanId?

    /// The name of this Span.
    public private(set) var name: String

    /// The kind of this Span.
    public private(set) var kind: SpanKind

    /// The start epoch time in nanos of this Span.
    public private(set) var startTime: Date

    /// The end epoch time in nanos of this Span
    public private(set) var endTime: Date?

    /// The attributes recorded for this Span.
    public private(set) var attributes = [String: AttributeValue]()

    /// The timed events recorded for this Span.
    public private(set) var events = [RecordingSpanEvent]()

    /// The links recorded for this Span.
    public private(set) var links = [RecordingSpanLink]()

    /// The Status.
    public private(set) var status: Status = .unset

    public static func == (lhs: SpanData, rhs: SpanData) -> Bool {
        return lhs.traceId == rhs.traceId &&
            lhs.spanId == rhs.spanId &&
            lhs.parentSpanId == rhs.parentSpanId &&
            lhs.name == rhs.name &&
            lhs.kind == rhs.kind &&
            lhs.status == rhs.status &&
            lhs.endTime == rhs.endTime &&
            lhs.startTime == rhs.startTime &&
            lhs.attributes == rhs.attributes &&
            lhs.events == rhs.events &&
            lhs.links == rhs.links
    }

    public init(
        traceId: TraceId,
        spanId: SpanId,
        parentSpanId: SpanId?,
        name: String,
        kind: SpanKind,
        startTime: Date,
        endTime: Date?,
        attributes: [String: AttributeValue] = [String: AttributeValue](),
        events: [RecordingSpanEvent] = [RecordingSpanEvent](),
        links: [RecordingSpanLink] = [RecordingSpanLink](),
        status: Status = .unset
    ) {
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.name = name
        self.kind = kind
        self.startTime = startTime
        self.endTime = endTime
        self.attributes = attributes
        self.events = events
        self.links = links
        self.status = status
    }
}
