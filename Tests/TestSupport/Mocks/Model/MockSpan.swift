//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import EmbraceSemantics
import Foundation

public class MockSpan: EmbraceSpan {
    public var context: EmbraceSpanContext
    public var parentSpanId: String?
    public var name: String
    public var type: EmbraceType
    public var _status: EmbraceSpanStatus
    public var startTime: Date
    public var endTime: Date?
    public var events: [EmbraceSpanEvent]
    public var links: [EmbraceSpanLink]
    public var sessionId: EmbraceIdentifier?
    public var processId: EmbraceIdentifier
    public var attributes: [String : String]

    public var status: EmbraceSpanStatus {
        _status
    }

    public init(
        id: String,
        traceId: String,
        parentSpanId: String? = nil,
        name: String,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date? = nil,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier,
        attributes: [String : String]
    ) {
        self.context = EmbraceSpanContext(spanId: id, traceId: traceId)
        self.parentSpanId = parentSpanId
        self.name = name
        self.type = type
        self._status = status
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
        self.links = links
        self.sessionId = sessionId
        self.processId = processId
        self.attributes = attributes
    }

    public func setStatus(_ status: EmbraceSpanStatus) {
        self._status = status
    }

    public func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: [String : String]) throws {
        events.append(EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: attributes))
    }

    public func addLink(spanId: String, traceId: String, attributes: [String : String]) throws {
        links.append(EmbraceSpanLink(spanId: spanId, traceId: traceId, attributes: attributes))
    }

    public func end(endTime: Date) {
        self.endTime = endTime
    }

    public func end() {
        end(endTime: Date())
    }

    public func setAttribute(key: String, value: String?) throws {
        attributes[key] = value
    }

}
