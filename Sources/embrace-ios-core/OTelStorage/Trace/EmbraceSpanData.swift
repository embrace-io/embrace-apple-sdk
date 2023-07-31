/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import GRDB

/// representation of all data collected by the Span.
public struct EmbraceSpanData: Equatable {
    /// The trace id for this span.
    public private(set) var traceId: TraceId

    /// The span id for this span.
    public private(set) var spanId: SpanId

    /// The trace flags for this span.
//    public private(set) var traceFlags = TraceFlags()

    /// The TraceState for this span.
//    public private(set) var traceState = TraceState()

    /// The parent SpanId. If the  Span is a root Span, the SpanId
    /// returned will be nil.
    public private(set) var parentSpanId: SpanId?

    /// The resource of this Span.
//    public private(set) var resource = Resource()     // TODO: Add resource

    /// The instrumentation scope specified when creating the tracer which produced this Span
//    public private(set) var instrumentationScope = InstrumentationScopeInfo()     // TODO: Add InstrumentationScopeInfo

    /// The name of this Span.
    public private(set) var name: String

    /// The kind of this Span.
    public private(set) var kind: SpanKind

    /// The start epoch time in nanos of this Span.
    public private(set) var startTime: Date

    /// The end epoch time in nanos of this Span
    public private(set) var endTime: Date

    /// The attributes recorded for this Span.
    public private(set) var attributes = [String: AttributeValue]()

    /// The timed events recorded for this Span.
//    public private(set) var events = [Event]()

    /// The links recorded for this Span.
//    public private(set) var links = [Link]()

    /// The Status.
//    public private(set) var status: Status = .unset

    /// True if the parent is on a different process, false if this is a root span.
//    public private(set) var hasRemoteParent: Bool = false

    /// True if the span has already been ended, false if not.
//    public private(set) var hasEnded: Bool = false

    /// The total number of {@link TimedEvent} events that were recorded on this span. This
    /// number may be larger than the number of events that are attached to this span, if the total
    /// number recorded was greater than the configured maximum value. See SpanLimits.maxNumberOfEvents
//    public private(set) var totalRecordedEvents: Int = 0

    /// The total number of  links that were recorded on this span. This number
    /// may be larger than the number of links that are attached to this span, if the total number
    /// recorded was greater than the configured maximum value. See SpanLimits.maxNumberOfLinks
//    public private(set) var totalRecordedLinks: Int = 0

    /// The total number of attributes that were recorded on this span. This number may be larger than
    /// the number of attributes that are attached to this span, if the total number recorded was
    /// greater than the configured maximum value. See SpanLimits.maxNumberOfAttributes
//    public private(set) var totalAttributeCount: Int = 0

    init(traceId: TraceId, spanId: SpanId, traceFlags: TraceFlags = TraceFlags(), traceState: TraceState = TraceState(), parentSpanId: SpanId? = nil, name: String, kind: SpanKind, startTime: Date, attributes: [String : AttributeValue] = [String: AttributeValue](), events: [Event] = [Event](), links: [Link] = [Link](), status: Status, endTime: Date, hasRemoteParent: Bool, hasEnded: Bool, totalRecordedEvents: Int, totalRecordedLinks: Int, totalAttributeCount: Int) {
        
        self.traceId = traceId
        self.spanId = spanId
//        self.traceFlags = traceFlags
//        self.traceState = traceState
        self.parentSpanId = parentSpanId
        self.name = name
        self.kind = kind
        self.startTime = startTime
        self.attributes = attributes
//        self.events = events
//        self.links = links
//        self.status = status
        self.endTime = endTime
//        self.hasRemoteParent = hasRemoteParent
//        self.hasEnded = hasEnded
//        self.totalRecordedEvents = totalRecordedEvents
//        self.totalRecordedLinks = totalRecordedLinks
//        self.totalAttributeCount = totalAttributeCount
    }

    public static func == (lhs: EmbraceSpanData, rhs: EmbraceSpanData) -> Bool {
        return lhs.traceId == rhs.traceId &&
            lhs.spanId == rhs.spanId &&
//            lhs.traceFlags == rhs.traceFlags &&
//            lhs.traceState == rhs.traceState &&
            lhs.parentSpanId == rhs.parentSpanId &&
            lhs.name == rhs.name &&
            lhs.kind == rhs.kind &&
//            lhs.status == rhs.status &&
            lhs.endTime == rhs.endTime &&
            lhs.startTime == rhs.startTime &&
//            lhs.hasRemoteParent == rhs.hasRemoteParent &&
//            lhs.resource == rhs.resource &&       // TODO: Add resource
//            lhs.attributes == rhs.attributes &&
//            lhs.events == rhs.events &&
//            lhs.links == rhs.links &&
//            lhs.hasEnded == rhs.hasEnded &&
//            lhs.totalRecordedEvents == rhs.totalRecordedEvents &&
//            lhs.totalRecordedLinks == rhs.totalRecordedLinks &&
//            lhs.totalAttributeCount == rhs.totalAttributeCount
            true
    }

    @discardableResult public mutating func settingName(_ name: String) -> EmbraceSpanData {
        self.name = name
        return self
    }

    @discardableResult public mutating func settingTraceId(_ traceId: TraceId) -> EmbraceSpanData {
        self.traceId = traceId
        return self
    }

    @discardableResult public mutating func settingSpanId(_ spanId: SpanId) -> EmbraceSpanData {
        self.spanId = spanId
        return self
    }

    @discardableResult public mutating func settingTraceFlags(_ traceFlags: TraceFlags) -> EmbraceSpanData {
//        self.traceFlags = traceFlags
        return self
    }

    @discardableResult public mutating func settingTraceState(_ traceState: TraceState) -> EmbraceSpanData {
//        self.traceState = traceState
        return self
    }

    @discardableResult public mutating func settingAttributes(_ attributes: [String: AttributeValue]) -> EmbraceSpanData {
//        self.attributes = attributes
        return self
    }

    @discardableResult public mutating func settingStartTime(_ time: Date) -> EmbraceSpanData {
        startTime = time
        return self
    }

    @discardableResult public mutating func settingEndTime(_ time: Date) -> EmbraceSpanData {
        endTime = time
        return self
    }

    @discardableResult public mutating func settingKind(_ kind: SpanKind) -> EmbraceSpanData {
        self.kind = kind
        return self
    }

    @discardableResult public mutating func settingLinks(_ links: [Link]) -> EmbraceSpanData {
//        self.links = links
        return self
    }

    @discardableResult public mutating func settingParentSpanId(_ parentSpanId: SpanId) -> EmbraceSpanData {
        self.parentSpanId = parentSpanId
        return self
    }

//    @discardableResult public mutating func settingResource(_ resource: Resource) -> SpanData {
//        self.resource = resource
//        return self
//    }

    @discardableResult public mutating func settingStatus(_ status: Status) -> EmbraceSpanData {
//        self.status = status
        return self
    }

    @discardableResult public mutating func settingEvents(_ events: [Event]) -> EmbraceSpanData {
//        self.events = events
        return self
    }

    @discardableResult public mutating func settingHasRemoteParent(_ hasRemoteParent: Bool) -> EmbraceSpanData {
//        self.hasRemoteParent = hasRemoteParent
        return self
    }

    @discardableResult public mutating func settingHasEnded(_ hasEnded: Bool) -> EmbraceSpanData {
//        self.hasEnded = hasEnded
        return self
    }

    @discardableResult public mutating func settingTotalRecordedEvents(_ totalRecordedEvents: Int) -> EmbraceSpanData {
//        self.totalRecordedEvents = totalRecordedEvents
        return self
    }

    @discardableResult public mutating func settingTotalRecordedLinks(_ totalRecordedLinks: Int) -> EmbraceSpanData {
//        self.totalRecordedLinks = totalRecordedLinks
        return self
    }

    @discardableResult public mutating func settingTotalAttributeCount(_ totalAttributeCount: Int) -> EmbraceSpanData {
//        self.totalAttributeCount = totalAttributeCount
        return self
    }
}

public extension EmbraceSpanData {
    /// Timed event.
    struct Event: Equatable, Codable {
        public private(set) var timestamp: Date
        public private(set) var name: String
        public private(set) var attributes: [String: AttributeValue]

        /// Creates an Event with the given time, name and empty attributes.
        /// - Parameters:
        ///   - nanotime: epoch time in nanos.
        ///   - name: the name of this Event.
        ///   - attributes: the attributes of this Event. Empty by default.
        public init(name: String, timestamp: Date, attributes: [String: AttributeValue]? = nil) {
            self.timestamp = timestamp
            self.name = name
            self.attributes = attributes ?? [String: AttributeValue]()
        }

        /// Creates an Event with the given time and event.
        /// - Parameters:
        ///   - nanotime: epoch time in nanos.
        ///   - event: the event.
        public init(timestamp: Date, event: Event) {
            self.init(name: event.name, timestamp: timestamp, attributes: event.attributes)
        }
    }
}

public extension EmbraceSpanData {
    struct Link: Codable {
        public let context: SpanContext
        public let attributes: [String: AttributeValue]

        public init(context: SpanContext, attributes: [String: AttributeValue] = [String: AttributeValue]()) {
            self.context = context
            self.attributes = attributes
        }
    }
}

public func == (lhs: EmbraceSpanData.Link, rhs: EmbraceSpanData.Link) -> Bool {
    return lhs.context == rhs.context && lhs.attributes == rhs.attributes
}

public func == (lhs: [EmbraceSpanData.Link], rhs: [EmbraceSpanData.Link]) -> Bool {
    return lhs.elementsEqual(rhs) { $0.context == $1.context && $0.attributes == $1.attributes }
}


extension EmbraceSpanData: TableRecord {
    public static let databaseTableName: String = "otel_spans"
}

extension EmbraceSpanData: FetchableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
}

extension EmbraceSpanData: PersistableRecord {
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
}

extension EmbraceSpanData: Codable {
    enum CodingKeys: String, CodingKey {
        case spanId
        case parentSpanId
        case traceId

        case name
        case kind
        case startTime
        case endTime
        case attributes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let hexSpanId = try container.decode(String.self, forKey: .spanId)
        let hexParentSpanId = try container.decodeIfPresent(String.self, forKey: .parentSpanId)
        let hexTraceId = try container.decode(String.self, forKey: .traceId)

        spanId = SpanId(fromHexString: hexSpanId)
        if let hexParentSpanId = hexParentSpanId {
            parentSpanId = SpanId(fromHexString: hexParentSpanId)
        }
        traceId = TraceId(fromHexString: hexTraceId)

        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(SpanKind.self, forKey: .kind)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        attributes = try container.decodeIfPresent([String : AttributeValue].self, forKey: .attributes) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spanId.hexString, forKey: .spanId)
        try container.encodeIfPresent(parentSpanId?.hexString, forKey: .parentSpanId)
        try container.encode(traceId.hexString, forKey: .traceId)

        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        
        try container.encode(attributes, forKey: .attributes)
    }


}

extension EmbraceSpanData: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(traceId)
        hasher.combine(spanId)
    }
}
