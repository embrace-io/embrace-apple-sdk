//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import Foundation

@testable import EmbraceCore

public protocol MockSpanDelegate: AnyObject {
    func onSpanEnded(_ span: EmbraceSpan)
}

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
    public var attributes: EmbraceAttributes

    public var status: EmbraceSpanStatus {
        _status
    }

    weak var delegate: MockSpanDelegate?

    public init(
        id: String = .randomSpanId(),
        traceId: String = TestConstants.traceId,
        parentSpanId: String? = nil,
        name: String,
        type: EmbraceType = .performance,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier = TestConstants.processId,
        attributes: EmbraceAttributes = [:],
        delegate: MockSpanDelegate? = nil
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
        self.delegate = delegate
    }

    public func setStatus(_ status: EmbraceSpanStatus) {
        self._status = status
    }

    public func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: EmbraceAttributes) throws {
        events.append(EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: attributes))
    }

    public func addLink(spanId: String, traceId: String, attributes: EmbraceAttributes) throws {
        links.append(EmbraceSpanLink(spanId: spanId, traceId: traceId, attributes: attributes))
    }

    public func end(endTime: Date) {
        self.endTime = endTime

        delegate?.onSpanEnded(self)
    }

    public func end() {
        end(endTime: Date())
    }

    public func setAttribute(key: String, value: EmbraceAttributeValue?) throws {
        attributes[key] = value
    }
}

extension MockSpan: EmbraceSpanInternalAttributes {
    public func _setInternalAttribute(key: String, value: EmbraceAttributeValue?) {
        try? setAttribute(key: key, value: value)
    }
}

extension MockSpan: EmbraceSpanSessionEvents {
    public func _addSessionEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        internalAttributes: EmbraceAttributes = [:],
        isInternal: Bool
    ) throws {
        try addEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: internalAttributes.merging(attributes) { (current, _) in current }
        )
    }
}
