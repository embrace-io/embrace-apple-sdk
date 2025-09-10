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
        get { state.safeValue.endTime }
        set { state.safeValue.endTime = newValue }
    }

    var events: [EmbraceSpanEvent] {
        get { state.safeValue.events }
        set { state.safeValue.events = newValue }
    }

    var links: [EmbraceSpanLink] {
        get { state.safeValue.links }
        set { state.safeValue.links = newValue }
    }

    var attributes: [String: String] {
        get { state.safeValue.attributes }
        set { state.safeValue.attributes = newValue }
    }

    struct MutableData {
        var status: EmbraceSpanStatus = .unset
        var endTime: Date? = nil
        var events: [EmbraceSpanEvent] = []
        var links: [EmbraceSpanLink] = []
        var attributes: [String: String] = [:]

        var internalEventCount: Int = 0
        var internalLinkCount: Int = 0
        var internalAttributeCount: Int = 0
    }
    let state = EmbraceMutex(MutableData())

    init(
        context: EmbraceSpanContext,
        parentSpanId: String?,
        name: String,
        type: EmbraceType = .performance,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: [String: String] = [:],
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
        state.safeValue.status = status
        handler?.onSpanStatusUpdated(self, status: status)
    }

    open func addEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
    ) throws {
        try _addEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            isInternal: false
        )
    }

    func _addEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        internalAttributes: [String: String] = [:],
        isInternal: Bool,
        isSessionEvent: Bool = false
    ) throws {

        var event: EmbraceSpanEvent?

        // apply limits?
        if isInternal {
            event = EmbraceSpanEvent(
                name: name,
                type: type,
                timestamp: timestamp,
                attributes: internalAttributes.merging(attributes) { (current, _) in current }
            )

        } else {
            let currentCount = state.withLock {
                $0.events.count - $0.internalEventCount
            }

            event = try handler?.createEvent(
                for: self,
                name: name,
                type: type,
                timestamp: timestamp,
                attributes: attributes,
                internalAttributes: internalAttributes,
                currentCount: currentCount,
                isSessionEvent: isSessionEvent
            )
        }

        guard let event else {
            return
        }

        // add event
        state.withLock {
            $0.events.append(event)

            if isInternal {
                $0.internalEventCount += 1
            }
        }
        handler?.onSpanEventAdded(self, event: event)
    }

    func addLink(
        spanId: String,
        traceId: String,
        attributes: [String: String] = [:]
    ) throws {
        guard let handler else {
            return
        }

        let currentCount = state.withLock {
            $0.events.count - $0.internalEventCount
        }

        let link = try handler.createLink(
            for: self,
            spanId: spanId,
            traceId: traceId,
            attributes: attributes,
            currentCount: currentCount
        )

        links.append(link)
        handler.onSpanLinkAdded(self, link: link)
    }

    open func setAttribute(key: String, value: String?) throws {
        try _setAttribute(
            key: key,
            value: value,
            isInternal: false
        )
    }

    func _setAttribute(key: String, value: String?, isInternal: Bool) throws {

        guard let handler else {
            return
        }

        var attribute: (String, String?) = (key, value)

        // apply limits?
        if !isInternal {
            let currentCount = state.withLock {
                $0.attributes.count - $0.internalAttributeCount
            }

            attribute = try handler.validateAttribute(
                for: self,
                key: key,
                value: value,
                currentCount: currentCount
            )
        }

        // update
        let update = state.withLock {
            guard $0.attributes[attribute.0] != attribute.1 else {
                return false
            }

            $0.attributes[attribute.0] = attribute.1

            if isInternal {
                $0.internalAttributeCount += value != nil ? 1 : -1
            }

            return true
        }

        if update {
            handler.onSpanAttributesUpdated(
                self,
                key: attribute.0,
                value: attribute.1,
                attributes: attributes
            )
        }
    }

    func end(endTime: Date) {
        self.endTime = endTime
        handler?.onSpanEnded(self, endTime: endTime)
    }

    func end() {
        end(endTime: Date())
    }
}

// MARK: Internal Attributes
protocol EmbraceSpanInternalAttributes {
    func _setInternalAttribute(key: String, value: String?)
}

extension DefaultEmbraceSpan: EmbraceSpanInternalAttributes {
    func _setInternalAttribute(key: String, value: String?) {
        try? _setAttribute(key: key, value: value, isInternal: true)
    }
}

extension EmbraceSpan {
    func setInternalAttribute(key: String, value: String?) {
        guard let span = self as? EmbraceSpanInternalAttributes else {
            return
        }

        span._setInternalAttribute(key: key, value: value)
    }
}

// MARK: Internal Session Events
protocol EmbraceSpanSessionEvents {
    func _addSessionEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String],
        internalAttributes: [String: String],
        isInternal: Bool
    ) throws
}

extension DefaultEmbraceSpan: EmbraceSpanSessionEvents {
    func _addSessionEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        internalAttributes: [String: String] = [:],
        isInternal: Bool
    ) throws {
        try _addEvent(
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
    func addSessionEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        internalAttributes: [String: String] = [:],
        isInternal: Bool
    ) throws {
        guard let span = self as? EmbraceSpanSessionEvents else {
            return
        }

        try span._addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            internalAttributes: internalAttributes,
            isInternal: isInternal
        )
    }
}
