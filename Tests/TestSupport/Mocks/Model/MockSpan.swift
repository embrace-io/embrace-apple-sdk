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

    /// Returns whether this span has already ended, and therefore no longer accepts changes.
    ///
    /// A span that ends becomes a completed record: its status, attributes, events and links are
    /// fixed from that point on. This matches the behavior of the span implementation used in
    /// production, so tests exercise the same rules the SDK applies at runtime.
    public var hasEnded: Bool {
        endTime != nil
    }

    /// Counts the changes that were dropped because the span had already ended.
    /// Tests can assert on this to verify a late mutation was refused rather than applied.
    public private(set) var ignoredMutationCount: Int = 0

    public func setStatus(_ status: EmbraceSpanStatus) {
        guard !hasEnded else {
            ignoredMutationCount += 1
            return
        }

        self._status = status
    }

    @discardableResult
    public func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: EmbraceAttributes) -> EmbraceSpanEvent? {
        guard !hasEnded else {
            ignoredMutationCount += 1
            return nil
        }

        let event = EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: attributes)
        events.append(event)
        return event
    }

    @discardableResult
    public func addLink(spanId: String, traceId: String, attributes: EmbraceAttributes) -> EmbraceSpanLink? {
        guard !hasEnded else {
            ignoredMutationCount += 1
            return nil
        }

        let link = EmbraceSpanLink(spanId: spanId, traceId: traceId, attributes: attributes)
        links.append(link)
        return link
    }

    public func end(endTime: Date) {
        guard !hasEnded else {
            ignoredMutationCount += 1
            return
        }

        self.endTime = endTime

        delegate?.onSpanEnded(self)
    }

    public func end() {
        end(endTime: Date())
    }

    public func setAttribute(key: String, value: EmbraceAttributeValue?) {
        guard !hasEnded else {
            ignoredMutationCount += 1
            return
        }

        attributes[key] = value
    }
}

extension MockSpan: EmbraceSpanInternalAttributes {
    public func _setInternalAttribute(key: String, value: EmbraceAttributeValue?) {
        setAttribute(key: key, value: value)
    }
}

extension MockSpan: EmbraceSpanSessionEvents {
    @discardableResult
    public func _addSessionEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        internalAttributes: EmbraceAttributes = [:],
        isInternal: Bool
    ) throws -> EmbraceSpanEvent? {
        return addEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: internalAttributes.merging(attributes) { (current, _) in current }
        )
    }
}
