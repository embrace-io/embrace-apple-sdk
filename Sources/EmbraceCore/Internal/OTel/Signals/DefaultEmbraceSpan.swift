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

    /// Whether the span has ended. An ended span no longer accepts changes to its status,
    /// attributes, events or links.
    ///
    /// A span exists in two places: the record Embrace stores and uploads, and the span the OTel
    /// pipeline exports. Storage accepts any mutation it is handed. The OTel side accepts none once
    /// the span has ended, because the bridge drops it from its span cache and the OTel SDK stops
    /// recording. Refusing the change up front keeps a late write from landing in the Embrace instance
    /// while being omitted from the OTel one.
    var hasEnded: Bool {
        state.safeValue.endTime != nil
    }

    /// Reports a change that was dropped because the span had already ended.
    private func logIgnoredMutation(_ description: String) {
        Embrace.logger.warning("Ignoring \(description) on span '\(self.name)': the span already ended.")
    }

    func setStatus(_ status: EmbraceSpanStatus) {
        guard !hasEnded else {
            logIgnoredMutation("status update")
            return
        }

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

        guard !hasEnded else {
            logIgnoredMutation("event '\(name)'")
            return nil
        }

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
        do {
            return try _addLink(
                spanId: spanId,
                traceId: traceId,
                attributes: attributes,
                isInternal: false
            )
        } catch {
            Embrace.logger.error("Failed to add link to span '\(self.name)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Adds a link, optionally bypassing the customer-facing link limit.
    ///
    /// Internal links are the SDK's own structural references between spans — the session part span
    /// pointing at its state spans, for instance — and the backend needs them regardless of how much
    /// customer telemetry the span is carrying. They are therefore exempt from the limit and counted
    /// separately, exactly as internal events and attributes are, so they never consume the
    /// customer's budget either.
    @discardableResult
    func _addLink(
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes = [:],
        isInternal: Bool
    ) throws -> EmbraceSpanLink? {

        // No handler means the span was constructed without one (e.g. read-only adapter / record),
        // so nothing would persist the link. Reported as a failure for internal callers too: they
        // rely on a nil return to detect a link that did not land, and appending to the in-memory
        // array while returning non-nil would tell them it succeeded.
        guard let handler else { return nil }

        guard !hasEnded else {
            logIgnoredMutation("link")
            return nil
        }

        let link: EmbraceSpanLink

        if isInternal {
            // Internal callers: skip the limiter and the sanitizer, as the internal event path does.
            link = EmbraceSpanLink(spanId: spanId, traceId: traceId, attributes: attributes)

            state.withLock {
                $0.links.append(link)
                $0.internalLinkCount += 1
            }

        } else {
            // The count the limit is checked against and the append that consumes a slot share a
            // single critical section. Reading the count under its own lock would let two concurrent
            // callers both pass the check and push the link count past the limit, and appending
            // through a get-then-set accessor would let one of the two links be lost entirely.
            link = try state.withLock {
                // Counted against the links already on this span, excluding the SDK's own.
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
        }

        handler.onSpanLinkAdded(self, link: link)
        return link
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

        guard !hasEnded else {
            logIgnoredMutation("attribute '\(key)'")
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
        // Claiming the end time and checking for a previous one happen together, so that two
        // threads ending the same span concurrently can't both notify the handler.
        let alreadyEnded = state.withLock { data -> Bool in
            guard data.endTime == nil else {
                return true
            }

            data.endTime = endTime
            return false
        }

        guard !alreadyEnded else {
            logIgnoredMutation("end")
            return
        }

        handler?.onSpanEnded(self, endTime: endTime)
    }

    func end() {
        end(endTime: Date())
    }
}

// MARK: Ending With an Error Code

/// Ends a span and records its outcome as one indivisible step.
protocol EmbraceSpanErrorCodeEnd {
    func _end(errorCode: EmbraceSpanErrorCode?, endTime: Date)
}

extension DefaultEmbraceSpan: EmbraceSpanErrorCodeEnd {

    /// What a successful claim reports once the lock is released.
    private struct EndOutcome {
        let status: EmbraceSpanStatus
        let errorCodeName: String?
        let endTime: Date
    }

    func _end(errorCode: EmbraceSpanErrorCode?, endTime: Date) {
        // The outcome and the end time are claimed together. Written one at a time, a span being
        // ended concurrently could keep half of an outcome — the error code attribute without the
        // error status that gives it meaning.
        let outcome: EndOutcome? = state.withLock { data in
            guard data.endTime == nil else {
                return nil
            }

            if let errorCode {
                data.attributes[SpanSemantics.keyErrorCode] = errorCode.name
                data.internalAttributeCount += 1
                data.status = .error
            } else {
                data.status = .ok
            }

            data.endTime = endTime

            return EndOutcome(
                status: data.status,
                errorCodeName: errorCode?.name,
                endTime: endTime
            )
        }

        guard let outcome else {
            logIgnoredMutation("end")
            return
        }

        // Notifications happen after the lock is released: a handler is free to read back the
        // span's state, and doing so takes this same non-recursive lock.
        if let errorCodeName = outcome.errorCodeName {
            handler?.onSpanAttributeUpdated(
                self,
                key: SpanSemantics.keyErrorCode,
                value: errorCodeName
            )
        }

        handler?.onSpanStatusUpdated(self, status: outcome.status)
        handler?.onSpanEnded(self, endTime: outcome.endTime)
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

// MARK: Internal Links

/// The SDK-only way to add a link. Deliberately not `public`: customer code cannot reach this, so
/// customer links always go through ``EmbraceSpan/addLink(spanId:traceId:attributes:)`` and remain
/// subject to the per-span limit.
protocol EmbraceSpanInternalLinks {
    @discardableResult
    func _addInternalLink(spanId: String, traceId: String, attributes: EmbraceAttributes) -> EmbraceSpanLink?
}

extension DefaultEmbraceSpan: EmbraceSpanInternalLinks {
    @discardableResult
    func _addInternalLink(
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes
    ) -> EmbraceSpanLink? {
        try? _addLink(spanId: spanId, traceId: traceId, attributes: attributes, isInternal: true)
    }
}

extension EmbraceSpan {
    /// Adds a structural link the SDK itself needs, exempt from the customer-facing link limit.
    ///
    /// - Returns: The stored link, or `nil` if this span cannot record internal links (a read-only
    ///   adapter, for instance).
    @discardableResult
    func addInternalLink(
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes = [:]
    ) -> EmbraceSpanLink? {
        guard let span = self as? EmbraceSpanInternalLinks else {
            return nil
        }

        return span._addInternalLink(spanId: spanId, traceId: traceId, attributes: attributes)
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
