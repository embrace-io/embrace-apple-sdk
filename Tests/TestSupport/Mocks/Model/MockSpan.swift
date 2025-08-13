//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import EmbraceSemantics
import Foundation

public class MockSpan: EmbraceSpan {
    public var id: String
    public var traceId: String
    public var parentSpanId: String?
    public var name: String
    public var type: EmbraceSemantics.EmbraceType
    public var status: EmbraceSemantics.EmbraceSpanStatus
    public var startTime: Date
    public var endTime: Date?
    public var events: [any EmbraceSemantics.EmbraceSpanEvent]
    public var links: [any EmbraceSemantics.EmbraceSpanLink]
    public var sessionId: EmbraceSemantics.EmbraceIdentifier?
    public var processId: EmbraceSemantics.EmbraceIdentifier
    public var attributes: [String : String]

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
        self.id = id
        self.traceId = traceId
        self.parentSpanId = parentSpanId
        self.name = name
        self.type = type
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
        self.links = links
        self.sessionId = sessionId
        self.processId = processId
        self.attributes = attributes
    }

    public func setStatus(_ status: EmbraceSemantics.EmbraceSpanStatus) {
        self.status = status
    }

    public func addEvent(_ event: any EmbraceSemantics.EmbraceSpanEvent) {
        events.append(event)
    }

    public func addLink(_ link: any EmbraceSemantics.EmbraceSpanLink) {
        links.append(link)
    }

    public func end(endTime: Date) {
        self.endTime = endTime
    }

    public func end() {
        end(endTime: Date())
    }

    public func setAttribute(key: String, value: String?) {
        attributes[key] = value
    }

}
