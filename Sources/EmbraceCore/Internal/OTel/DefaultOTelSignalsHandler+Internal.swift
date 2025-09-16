//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

// MARK: InternalOTelSignalsHandler
extension DefaultOTelSignalsHandler: InternalOTelSignalsHandler {
    public func _createSpan(
        name: String,
        parentSpan: EmbraceSpan? = nil,
        type: EmbraceType,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: [String: String] = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
        isInternal: Bool = true
    ) throws -> EmbraceSpan {

        guard isInternal || limiter.shouldCreateCustomSpan() else {
            throw EmbraceOTelError.spanLimitReached
        }

        // sanitize name
        let finalName = isInternal ? name : sanitizer.sanitizeSpanName(name)

        // add embrace specific attributes
        let sanitizedAttributes = isInternal ? attributes : sanitizer.sanitizeSpanAttributes(attributes)
        var internalAttributes = [String: String]()
        internalAttributes.setEmbraceType(type)
        internalAttributes.setEmbraceSessionId(sessionController?.currentSession?.id)

        let finalAttributes = internalAttributes.merging(sanitizedAttributes) { (current, _) in current }

        // create span context
        let context = bridge.startSpan(
            name: finalName,
            parentSpan: parentSpan,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: finalAttributes
        )

        // get auto termination code from parent if needed
        var code = autoTerminationCode
        if let parentSpan, code == nil {
            code = cache.safeValue.autoTerminationSpans[parentSpan.context.spanId]?.autoTerminationCode
        }

        // create span
        let span = newSpan(
            context: context,
            parentSpanId: parentSpan?.context.spanId,
            name: finalName,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: finalAttributes,
            internalAttributeCount: internalAttributes.count,
            autoTerminationCode: code,
            isInternal: isInternal
        )

        // cache auto termination spans
        if code != nil {
            cache.withLock {
                $0.autoTerminationSpans[context.spanId] = span
            }
        }

        // save span
        storage?.upsertSpan(span)

        return span
    }

    public func _addSessionEvent(
        name: String,
        type: EmbraceType? = nil,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        isInternal: Bool = true
    ) throws {

        guard let span = sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession
        }

        try span.addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            isInternal: isInternal
        )
    }

    public func _log(
        _ message: String,
        severity: EmbraceLogSeverity = .info,
        type: EmbraceType,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default,
        isInternal: Bool = true,
        send: Bool = true
    ) throws {

        guard isInternal || limiter.shouldCreateLog(type: type, severity: severity) else {
            throw EmbraceOTelError.logLimitReached
        }

        logController?.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attributes: isInternal ? attributes : sanitizer.sanitizeLogAttributes(attributes),
            stackTraceBehavior: stackTraceBehavior,
            send: send
        ) { [weak self] log in
            if let log {
                self?.bridge.createLog(log)
            }
        }
    }

    // ends all the cached auto-termination spans
    public func autoTerminateSpans() {
        cache.withLock {
            let now = Date()

            for span in $0.autoTerminationSpans.values {
                let code = span.autoTerminationCode ?? .unknown
                span.end(errorCode: code, endTime: now)
            }

            $0.autoTerminationSpans.removeAll()
        }

        limiter.reset()
    }

    // creates a log that is not saved nor added to the batch
    // only used for logs that are handled in a special manner
    // but still need to be exported externally (i.e crash logs)
    func exportLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
    ) {
        try? _log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            isInternal: true,
            send: false
        )
    }

    // creates a new span
    func newSpan(
        context: EmbraceSpanContext,
        parentSpanId: String?,
        name: String,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: [String: String],
        internalAttributeCount: Int,
        autoTerminationCode: EmbraceSpanErrorCode?,
        isInternal: Bool
    ) -> DefaultEmbraceSpan {

        if isInternal {
            return InternalEmbraceSpan(
                context: context,
                parentSpanId: parentSpanId,
                name: name,
                type: type,
                status: status,
                startTime: startTime,
                endTime: endTime,
                events: events,
                links: links,
                attributes: attributes,
                internalAttributeCount: internalAttributeCount,
                sessionId: sessionController?.currentSession?.id,
                processId: ProcessIdentifier.current,
                autoTerminationCode: autoTerminationCode,
                handler: self
            )
        }

        return DefaultEmbraceSpan(
            context: context,
            parentSpanId: parentSpanId,
            name: name,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            internalAttributeCount: internalAttributeCount,
            sessionId: sessionController?.currentSession?.id,
            processId: ProcessIdentifier.current,
            autoTerminationCode: autoTerminationCode,
            handler: self
        )
    }
}

// MARK: EmbraceSpanDelegate
extension DefaultOTelSignalsHandler: EmbraceSpanDelegate {
    func onSpanStatusUpdated(_ span: EmbraceSpan, status: EmbraceSpanStatus) {
        bridge.updateSpanStatus(span, status: status)
        storage?.setSpanStatus(id: span.context.spanId, traceId: span.context.traceId, status: status)
    }

    func onSpanEventAdded(_ span: EmbraceSpan, event: EmbraceSpanEvent) {
        bridge.addSpanEvent(span, event: event)
        storage?.addSpanEvent(id: span.context.spanId, traceId: span.context.traceId, event: event)
    }

    func onSpanLinkAdded(_ span: EmbraceSpan, link: EmbraceSpanLink) {
        bridge.addSpanLink(span, link: link)
        storage?.addSpanLink(id: span.context.spanId, traceId: span.context.traceId, link: link)
    }

    func onSpanAttributesUpdated(_ span: EmbraceSpan, key: String, value: String?, attributes: [String: String]) {
        bridge.updateSpanAttribute(span, key: key, value: value)
        storage?.setSpanAttributes(id: span.context.spanId, traceId: span.context.traceId, attributes: attributes)
    }

    func onSpanEnded(_ span: any EmbraceSpan, endTime: Date) {
        bridge.endSpan(span, endTime: endTime)
        storage?.endSpan(id: span.context.spanId, traceId: span.context.traceId, endTime: endTime)
    }
}

// MARK: EmbraceSpanDataSource
extension DefaultOTelSignalsHandler: EmbraceSpanDataSource {
    func createEvent(
        for span: EmbraceSpan,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String],
        internalAttributes: [String: String],
        currentCount: Int,
        isSessionEvent: Bool = false
    ) throws -> EmbraceSpanEvent {

        // check limit
        if isSessionEvent {
            guard limiter.shouldAddSessionEvent(ofType: type) else {
                throw EmbraceOTelError.spanEventLimitReached("Events limit reached for session span!")
            }
        } else {
            guard limiter.shouldAddSpanEvent(currentCount: currentCount) else {
                throw EmbraceOTelError.spanEventLimitReached("Events limit reached for span \(span.name)")
            }
        }

        let sanitizedAttributes = sanitizer.sanitizeSpanEventAttributes(attributes)
        let finalAttributes = internalAttributes.merging(sanitizedAttributes) { (current, _) in current }

        return EmbraceSpanEvent(
            name: sanitizer.sanitizeSpanEventName(name),
            type: type,
            timestamp: timestamp,
            attributes: finalAttributes
        )
    }

    func createLink(
        for span: EmbraceSpan,
        spanId: String,
        traceId: String,
        attributes: [String: String],
        currentCount: Int
    ) throws -> EmbraceSpanLink {

        // check limit
        guard limiter.shouldAddSpanLink(currentCount: currentCount) else {
            throw EmbraceOTelError.spanLinkLimitReached("Links limit reached for span \(span.name)")
        }

        return EmbraceSpanLink(
            spanId: spanId,
            traceId: traceId,
            attributes: sanitizer.sanitizeSpanLinkAttributes(attributes)
        )
    }

    func validateAttribute(
        for span: EmbraceSpan,
        key: String,
        value: String?,
        currentCount: Int
    ) throws -> (String, String?) {

        // no limits when removing a key
        guard let value else {
            return (key, value)
        }

        // check limit
        let finalKey = sanitizer.sanitizeAttributeKey(key)
        guard span.attributes[finalKey] != nil || limiter.shouldAddSpanAttribute(currentCount: currentCount) else {
            throw EmbraceOTelError.spanAttributeLimitReached("Attributes limit reached for span \(span.name)")
        }

        let finalValue = sanitizer.sanitizeAttributeValue(value)

        return (finalKey, finalValue)
    }
}

// MARK: EmbraceOTelDelegate
extension DefaultOTelSignalsHandler: EmbraceOTelDelegate {
    public func onStartSpan(_ span: EmbraceSpan) {

        // check limits
        var onlyUpdate = false
        if !limiter.shouldCreateCustomSpan() {
            onlyUpdate = true
            Embrace.logger.warning("Limit reached for spans on the current Embrace session!")
        }

        // update db
        storage?.upsertSpan(span, onlyUpdate: onlyUpdate)
    }

    public func onEndSpan(_ span: EmbraceSpan) {
        // update db
        storage?.upsertSpan(span, onlyUpdate: true)
    }

    public func onEmitLog(_ log: EmbraceLog) {

        guard limiter.shouldCreateLog(type: log.type, severity: log.severity) else {
            Embrace.logger.warning("Limit reached for logs on the current Embrace session!")
            return
        }

        // add log
        logController?.addLog(log)
    }
}
