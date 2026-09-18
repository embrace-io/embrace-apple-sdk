//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// Internal implementation of the `EmbraceSpan`.
/// Users of the SDK are expected to create these through the public interface and hold them.
/// This class internally communicates with the `OTelSingalsHandler`.
class DefaultEmbraceSpan: EmbraceSpan {

    let context: EmbraceSpanContext
    let parentSpanId: String?
    let name: String
    let type: EmbraceType
    let startTime: Date
    let sessionId: EmbraceIdentifier?
    let processId: EmbraceIdentifier
    let autoTerminationCode: EmbraceSpanErrorCode?

    weak var handler: EmbraceSpanHandler?

    var status: EmbraceSpanStatus {
        state.safeValue.status
    }

    var endTime: Date? {
        state.safeValue.endTime
    }

    var events: [EmbraceSpanEvent] {
        state.safeValue.events
    }

    var links: [EmbraceSpanLink] {
        state.safeValue.links
    }

    var attributes: EmbraceAttributes {
        state.safeValue.attributes
    }

    /// All mutable state of the span, guarded by `state`.
    ///
    /// Mutations must go through `state.withLock { }` so that the read and the write happen in a
    /// single critical section. Mutating a single field through a get-then-set accessor would copy
    /// the whole struct, mutate the copy, and write it back, allowing a concurrent mutation of any
    /// other field to be silently lost.
    struct MutableData {
        var status: EmbraceSpanStatus = .unset
        var endTime: Date? = nil
        var events: [EmbraceSpanEvent] = []
        var links: [EmbraceSpanLink] = []
        var attributes: EmbraceAttributes = [:]

        var internalEventCount: Int = 0
        var internalLinkCount: Int = 0
        var internalAttributeCount: Int = 0
    }
    let state = EmbraceMutex(MutableData())

    init(
        context: EmbraceSpanContext,
        parentSpanId: String? = nil,
        name: String,
        type: EmbraceType = .performance,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: EmbraceAttributes = [:],
        internalAttributeCount: Int = 0,
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier = ProcessIdentifier.current,
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
        handler: EmbraceSpanHandler? = nil
    ) {
        self.context = context
        self.parentSpanId = parentSpanId
        self.name = name
        self.type = type
        self.startTime = startTime
        self.sessionId = sessionId
        self.processId = processId
        self.autoTerminationCode = autoTerminationCode
        self.handler = handler

        state.withLock {
            $0.status = status
            $0.endTime = endTime
            $0.events = events
            $0.links = links
            $0.attributes = attributes
            $0.internalAttributeCount = internalAttributeCount
        }
    }

    func setStatus(_ status: EmbraceSpanStatus) {
        state.withLock { $0.status = status }
        handler?.onSpanStatusUpdated(self, status: status)
    }

    @discardableResult
    open func addEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) -> EmbraceSpanEvent? {
        do {
            return try _addEvent(
                name: name,
                type: type,
                timestamp: timestamp,
                attributes: attributes,
                isInternal: false
            )
        } catch {
            // _addEvent throws only on limit overflow; no-handler returns nil silently.
            Embrace.logger.warning("Failed to add event '\(name)': \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func _addEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        internalAttributes: EmbraceAttributes = [:],
        isInternal: Bool,
        isSessionEvent: Bool = false
    ) throws -> EmbraceSpanEvent? {

        let event: EmbraceSpanEvent

        if isInternal {
            // Internal callers: skip limits; merge internalAttributes onto the user's attributes.
            event = EmbraceSpanEvent(
                name: name,
                type: type,
                timestamp: timestamp,
                attributes: internalAttributes.merging(attributes) { (current, _) in current }
            )

            state.withLock {
                $0.events.append(event)
                $0.internalEventCount += 1
            }

        } else {
            // No handler means the span was constructed without one (e.g. read-only adapter / record).
            // Match today's silent skip — return nil.
            guard let handler else { return nil }

            // The count the limit is checked against and the append that consumes a slot share a
            // single critical section. Reading the count under its own lock would let two concurrent
            // callers both pass the check and push the event count past the limit.
            event = try state.withLock {
                let currentCount = $0.events.count - $0.internalEventCount

                let event = try handler.createEvent(
                    forSpanNamed: self.name,
                    name: name,
                    type: type,
                    timestamp: timestamp,
                    attributes: attributes,
                    internalAttributes: internalAttributes,
                    currentCount: currentCount,
                    isSessionEvent: isSessionEvent
                )

                $0.events.append(event)
                return event
            }
        }

        handler?.onSpanEventAdded(self, event: event)
        return event
    }

    @discardableResult
    func addLink(
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes = [:]
    ) -> EmbraceSpanLink? {
        guard let handler else {
            return nil
        }

        do {
            // The count the limit is checked against and the append that consumes a slot share a
            // single critical section. Reading the count under its own lock would let two concurrent
            // callers both pass the check and push the link count past the limit, and appending
            // through a get-then-set accessor would let one of the two links be lost entirely.
            let link = try state.withLock {
                let currentCount = $0.links.count - $0.internalLinkCount

                let link = try handler.createLink(
                    forSpanNamed: self.name,
                    spanId: spanId,
                    traceId: traceId,
                    attributes: attributes,
                    currentCount: currentCount
                )

                $0.links.append(link)
                return link
            }

            handler.onSpanLinkAdded(self, link: link)
            return link
        } catch {
            Embrace.logger.error("Failed to add link to span '\(self.name)': \(error.localizedDescription)")
            return nil
        }
    }

    open func setAttribute(key: String, value: EmbraceAttributeValue?) {
        do {
            try _setAttribute(
                key: key,
                value: value,
                isInternal: false
            )
        } catch {
            Embrace.logger.warning("Failed to set attribute to span '\(self.name)': \(error.localizedDescription)")
        }
    }

    func _setAttribute(key: String, value: EmbraceAttributeValue?, isInternal: Bool) throws {

        guard let handler else {
            return
        }

        // The count the limit is checked against and the write that consumes a slot share a single
        // critical section. Reading the count under its own lock would let two concurrent callers
        // both pass the check and push the attribute count past the limit.
        let attribute = try state.withLock { data -> (String, EmbraceAttributeValue?) in
            var attribute: (String, EmbraceAttributeValue?) = (key, value)

            // apply limits?
            if !isInternal {
                attribute = try handler.validateAttribute(
                    forSpanNamed: self.name,
                    key: key,
                    value: value,
                    currentAttributes: data.attributes,
                    currentCount: data.attributes.count - data.internalAttributeCount
                )
            }

            // only count the attribute when its presence actually changes, otherwise
            // overwriting an existing key or clearing an absent one skews the count
            let existed = data.attributes[attribute.0] != nil
            data.attributes[attribute.0] = attribute.1

            if isInternal, existed != (attribute.1 != nil) {
                data.internalAttributeCount += attribute.1 != nil ? 1 : -1
            }

            return attribute
        }

        handler.onSpanAttributeUpdated(self, key: attribute.0, value: attribute.1)
    }

    func end(endTime: Date) {
        state.withLock { $0.endTime = endTime }
        handler?.onSpanEnded(self, endTime: endTime)
    }

    func end() {
        end(endTime: Date())
    }
}

// MARK: Internal Attributes
protocol EmbraceSpanInternalAttributes {
    func _setInternalAttribute(key: String, value: EmbraceAttributeValue?)
}

extension DefaultEmbraceSpan: EmbraceSpanInternalAttributes {
    func _setInternalAttribute(key: String, value: EmbraceAttributeValue?) {
        try? _setAttribute(key: key, value: value, isInternal: true)
    }
}

extension EmbraceSpan {
    func setInternalAttribute(key: String, value: EmbraceAttributeValue?) {
        guard let span = self as? EmbraceSpanInternalAttributes else {
            return
        }

        span._setInternalAttribute(key: key, value: value)
    }
}

// MARK: Internal Session Events
protocol EmbraceSpanSessionEvents {
    @discardableResult
    func _addSessionEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes,
        internalAttributes: EmbraceAttributes,
        isInternal: Bool
    ) throws -> EmbraceSpanEvent?
}

extension DefaultEmbraceSpan: EmbraceSpanSessionEvents {
    @discardableResult
    func _addSessionEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        internalAttributes: EmbraceAttributes = [:],
        isInternal: Bool
    ) throws -> EmbraceSpanEvent? {
        return try _addEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            internalAttributes: internalAttributes,
            isInternal: isInternal,
            isSessionEvent: true
        )
    }
}

extension EmbraceSpan {
    @discardableResult
    func addSessionEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        internalAttributes: EmbraceAttributes = [:],
        isInternal: Bool
    ) throws -> EmbraceSpanEvent? {
        guard let span = self as? EmbraceSpanSessionEvents else {
            return nil
        }

        return try span._addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            internalAttributes: internalAttributes,
            isInternal: isInternal
        )
    }
}
