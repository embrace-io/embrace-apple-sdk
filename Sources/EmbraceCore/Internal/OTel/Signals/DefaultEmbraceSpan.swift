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
        get { state.safeValue.status }
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

    var attributes: [String : String] {
        get { state.safeValue.attributes }
        set { state.safeValue.attributes = newValue }
    }

    struct MutableData {
        var status: EmbraceSpanStatus = .unset
        var endTime: Date? = nil
        var events: [EmbraceSpanEvent] = []
        var links: [EmbraceSpanLink] = []
        var attributes: [String : String] = [:]

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
    
    func addEvent(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: [String : String] = [:]
    ) throws {
        guard let handler else {
            return
        }

        let event = try handler.createEvent(
            for: self,
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            internalCount: state.safeValue.internalEventCount,
            isInternal: false
        )

        events.append(event)
        handler.onSpanEventAdded(self, event: event)
    }

    func addLink(
        spanId: String,
        traceId: String,
        attributes: [String : String] = [:]
    ) throws {
        guard let handler else {
            return
        }

        let link = try handler.createLink(
            for: self,
            spanId: spanId,
            traceId: traceId,
            attributes: attributes,
            internalCount: state.safeValue.internalLinkCount,
            isInternal: false
        )

        links.append(link)
        handler.onSpanLinkAdded(self, link: link)
    }

    func setAttribute(key: String, value: String?) throws {
        try _setAttribute(key: key, value: value, isInternal: false)
    }

    func _setAttribute(key: String, value: String?, isInternal: Bool) throws {
        guard let handler else {
            return
        }

        let attribute = try handler.validateAttribute(
            for: self,
            key: key,
            value: value,
            internalCount: state.safeValue.internalAttributeCount,
            isInternal: isInternal
        )

        // update
        let update = state.withLock {
            guard $0.attributes[attribute.0] != attribute.1 else {
                return false
            }

            $0.attributes[attribute.0] = attribute.1

            if isInternal {
                $0.internalAttributeCount += attribute.1 == nil ? -1 : 1
            }

            return true
        }

        if update {
            handler.onSpanAttributesUpdated(self, attributes: attributes)
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

extension EmbraceSpan {
    func addSessionEvent(_ event: EmbraceSpanEvent, isInternal: Bool = true) {
        guard let internalSpan = self as? DefaultEmbraceSpan else {
            return
        }

        if isInternal {
            internalSpan.state.safeValue.internalEventCount += 1
        }

        internalSpan.events.append(event)
        internalSpan.handler?.onSpanEventAdded(self, event: event)
    }

    func addSessionLink(_ link: EmbraceSpanLink, isInternal: Bool = true) {
        guard let internalSpan = self as? DefaultEmbraceSpan else {
            return
        }

        if isInternal {
            internalSpan.state.safeValue.internalLinkCount += 1
        }

        internalSpan.links.append(link)
        internalSpan.handler?.onSpanLinkAdded(self, link: link)
    }

    func setInternalAttribute(key: String, value: String?) {
        guard let internalSpan = self as? DefaultEmbraceSpan else {
            try? setAttribute(key: key, value: value)
            return
        }

        try? internalSpan._setAttribute(key: key, value: value, isInternal: true)
    }
}
