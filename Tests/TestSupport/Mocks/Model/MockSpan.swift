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
    public var startTime: Date
    public var sessionId: EmbraceIdentifier?
    public var processId: EmbraceIdentifier

    /// Mutable span state, guarded like the real `DefaultEmbraceSpan` guards its own.
    ///
    /// A span can legitimately be written from several threads at once — `StateRecorder`, for one,
    /// performs its span I/O outside its own lock on purpose — so an unsynchronized array here
    /// corrupts memory rather than failing a test.
    private let lock = NSLock()
    private var _endTime: Date?
    private var _events: [EmbraceSpanEvent]
    private var _links: [EmbraceSpanLink]
    private var _attributes: EmbraceAttributes
    private var _statusStorage: EmbraceSpanStatus

    private func synced<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public var endTime: Date? {
        get { synced { _endTime } }
        set { synced { _endTime = newValue } }
    }

    public var events: [EmbraceSpanEvent] {
        get { synced { _events } }
        set { synced { _events = newValue } }
    }

    public var links: [EmbraceSpanLink] {
        get { synced { _links } }
        set { synced { _links = newValue } }
    }

    public var attributes: EmbraceAttributes {
        get { synced { _attributes } }
        set { synced { _attributes = newValue } }
    }

    // swiftlint:disable:next identifier_name
    public var _status: EmbraceSpanStatus {
        get { synced { _statusStorage } }
        set { synced { _statusStorage = newValue } }
    }

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
        self._statusStorage = status
        self.startTime = startTime
        self._endTime = endTime
        self._events = events
        self._links = links
        self.sessionId = sessionId
        self.processId = processId
        self._attributes = attributes
        self.delegate = delegate
    }

    public func setStatus(_ status: EmbraceSpanStatus) {
        self._status = status
    }

    @discardableResult
    public func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: EmbraceAttributes) -> EmbraceSpanEvent? {
        let event = EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: attributes)
        synced { _events.append(event) }
        return event
    }

    @discardableResult
    public func addLink(spanId: String, traceId: String, attributes: EmbraceAttributes) -> EmbraceSpanLink? {
        let link = EmbraceSpanLink(spanId: spanId, traceId: traceId, attributes: attributes)
        synced { _links.append(link) }
        return link
    }

    public func end(endTime: Date) {
        self.endTime = endTime

        delegate?.onSpanEnded(self)
    }

    public func end() {
        end(endTime: Date())
    }

    public func setAttribute(key: String, value: EmbraceAttributeValue?) {
        synced { _attributes[key] = value }
    }
}

extension MockSpan: EmbraceSpanInternalAttributes {
    public func _setInternalAttribute(key: String, value: EmbraceAttributeValue?) {
        setAttribute(key: key, value: value)
    }
}

extension MockSpan: EmbraceSpanInternalLinks {
    /// The mock enforces no limits, so an internal link is stored the same way a customer one is —
    /// what matters for tests is that the internal path exists and is reachable.
    @discardableResult
    public func _addInternalLink(
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes
    ) -> EmbraceSpanLink? {
        addLink(spanId: spanId, traceId: traceId, attributes: attributes)
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
