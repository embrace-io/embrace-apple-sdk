//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

/// Class used to generate OTel signals and add them to the Embrace sessions.
/// These signals will also be exported on the Embrace Tracer if the SDK is initialized with
/// a custom OTel `SpanProcessor` or `SpanExporter`.
@objc
public class EmbraceOTelSignalsHandler: NSObject, InternalOTelSignalsHandler {

    let storage: EmbraceStorage?
    let sessionController: SessionController?
    let logController: LogController?
    let limiter: OTelSignalsLimiter
    let sanitizer: OTelSignalsSanitizer
    let bridge: EmbraceOTelSignalBridge

    struct Cache {
        var externalSpanCount: Int = 0
        var internalSpanCount: Int = 0
        var spanCountByType: [String: Int] = [:]
        var autoTerminationSpans: [String: DefaultEmbraceSpan] = [:]
    }
    private let cache = EmbraceMutex(Cache())

    static let attachmentLimit: Int = 5
    static let attachmentSizeLimit: Int = 1_048_576  // 1 MiB

    init(
        storage: EmbraceStorage?,
        sessionController: SessionController?,
        logController: LogController?,
        limiter: OTelSignalsLimiter,
        sanitizer: OTelSignalsSanitizer = DefaultOtelSignalsSanitizer(),
        bridge: EmbraceOTelSignalBridge = DefaultOTelSignalBridge()
    ) {
        self.storage = storage
        self.sessionController = sessionController
        self.logController = logController
        self.limiter = limiter
        self.sanitizer = sanitizer
        self.bridge = bridge
    }

    /// Creates a new span to be included in the current Embrace session.
    /// - Parameters:
    ///   - name: Name of the span.
    ///   - parentSpan: Parent of the span, if any.
    ///   - type: Embrace specific type of the span. Defaults to `.performance`.
    ///   - status: Initial status of the span. Defaults to `.unset`.
    ///   - startTime: Start time of the span. Defaults to the current time.
    ///   - endTime: End time of the span, if any.
    ///   - events: Events for the span.
    ///   - links: Links for the span.
    ///   - attributes: Attributes of the span.
    ///   - autoTerminationCode: If a code is passed, the span will be automatically ended when the current Embrace session ends and will have a special attribute with the given code.
    /// - Returns: The newly created `EmbraceSpan`.
    /// - Throws: `EmbraceOTelError.spanLimitReached` if the span limit has been reached for the current Embrace session.
    @discardableResult
    public func createSpan(
        name: String,
        parentSpan: EmbraceSpan? = nil,
        type: EmbraceType = .performance,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: [String: String] = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil
    ) throws -> EmbraceSpan {

        guard limiter.shouldCreateCustomSpan() else {
            throw EmbraceOTelError.spanLimitReached
        }

        // sanitize name
        let finalName = sanitizer.sanitizeSpanName(name)

        // add embrace specific attributes
        let sanitizedAttributes = sanitizer.sanitizeSpanAttributes(attributes)
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
        if let parentSpan,
            code == nil
        {
            code = cache.safeValue.autoTerminationSpans[parentSpan.context.spanId]?.autoTerminationCode
        }

        // create span
        let span = DefaultEmbraceSpan(
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
            sessionId: sessionController?.currentSession?.id,
            processId: ProcessIdentifier.current,
            autoTerminationCode: code,
            handler: self
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

    /// Adds the given `EmbraceSpanEvent` to the current Embrace session.
    /// - Parameter name: Name of the event.
    /// - Parameter type: Embrace specific type of the event, if any.
    /// - Parameter timestamp: Timestamp of the event.
    /// - Parameter attributes: Attributes of the event.
    /// - Throws: `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    public func addSessionEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String]
    ) throws {

        guard let span = sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession
        }

        guard limiter.shouldAddSessionEvent(ofType: type) else {
            throw EmbraceOTelError.spanEventLimitReached("Limit reached for the span event type!")
        }

        let event = EmbraceSpanEvent(
            name: sanitizer.sanitizeSpanEventName(name),
            type: type,
            timestamp: timestamp,
            attributes: sanitizer.sanitizeSpanEventAttributes(attributes)
        )

        span.addSessionEvent(event, isInternal: false)
    }

    /// Emits a new log.
    /// - Parameters:
    ///   - message: Message of the log
    ///   - severity: Severity of the log
    ///   - type: Type of the log
    ///   - timestamp: Timestamp of the log
    ///   - attachment: Attachment data for the log
    ///   - attributes: Attributes of the log
    ///   - stackTraceBehavior: Behavior that detemines if a stack trace has to be generated for the log.
    /// - Throws: `EmbraceOTelError.logLimitReached` if the log limit has been reached for the current Embrace session.
    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .defaultStackTrace()
    ) throws {
        try _log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior
        )
    }
}

// MARK: Internal

extension EmbraceOTelSignalsHandler {

    // ends all the cached auto-termination spans
    public func autoTerminateSpans() {
        cache.withLock {
            let now = Date()

            for span in $0.autoTerminationSpans.values {
                let code = span.autoTerminationCode ?? .unknown
                span.setInternalAttribute(key: SpanSemantics.keyErrorCode, value: code.name)
                span.setStatus(.error)
                span.end(endTime: now)
            }

            $0.autoTerminationSpans.removeAll()
        }
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
            send: false
        )
    }

    public func _log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .defaultStackTrace(),
        send: Bool = true
    ) throws {

        guard limiter.shouldCreateLog(type: type, severity: severity) else {
            throw EmbraceOTelError.logLimitReached
        }

        logController?.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attributes: sanitizer.sanitizeLogAttributes(attributes),
            stackTraceBehavior: stackTraceBehavior,
            send: send
        ) { [weak self] log in
            if let log {
                self?.bridge.createLog(log)
            }
        }
    }
}

// MARK: EmbraceSpanDelegate
extension EmbraceOTelSignalsHandler: EmbraceSpanDelegate {
    func onSpanStatusUpdated(_ span: EmbraceSpan, status: EmbraceSpanStatus) {
        storage?.setSpanStatus(id: span.context.spanId, traceId: span.context.traceId, status: status)
    }

    func onSpanEventAdded(_ span: EmbraceSpan, event: EmbraceSpanEvent) {
        storage?.addSpanEvent(id: span.context.spanId, traceId: span.context.traceId, event: event)
    }

    func onSpanLinkAdded(_ span: EmbraceSpan, link: EmbraceSpanLink) {
        storage?.addSpanLink(id: span.context.spanId, traceId: span.context.traceId, link: link)
    }

    func onSpanAttributesUpdated(_ span: EmbraceSpan, attributes: [String: String]) {
        storage?.setSpanAttributes(id: span.context.spanId, traceId: span.context.traceId, attributes: attributes)
    }

    func onSpanEnded(_ span: any EmbraceSpan, endTime: Date) {
        storage?.endSpan(id: span.context.spanId, traceId: span.context.traceId, endTime: endTime)
    }
}

// MARK: EmbraceSpanDataSource
extension EmbraceOTelSignalsHandler: EmbraceSpanDataSource {
    func createEvent(
        for span: EmbraceSpan,
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String],
        internalCount: Int,
        isInternal: Bool
    ) throws -> EmbraceSpanEvent {

        // no limits for internal events
        guard !isInternal else {
            return EmbraceSpanEvent(
                name: name,
                type: type,
                timestamp: timestamp,
                attributes: attributes
            )
        }

        // check limit
        guard limiter.shouldAddSpanEvent(currentCount: span.events.count - internalCount) else {
            throw EmbraceOTelError.spanEventLimitReached("Events limit reached for span \(span.name)")
        }

        return EmbraceSpanEvent(
            name: sanitizer.sanitizeSpanEventName(name),
            type: type,
            timestamp: timestamp,
            attributes: sanitizer.sanitizeSpanEventAttributes(attributes)
        )
    }

    func createLink(
        for span: EmbraceSpan,
        spanId: String,
        traceId: String,
        attributes: [String: String],
        internalCount: Int,
        isInternal: Bool
    ) throws -> EmbraceSpanLink {

        // no limits for internal links
        guard !isInternal else {
            return EmbraceSpanLink(
                spanId: spanId,
                traceId: traceId,
                attributes: attributes
            )
        }

        // check limit
        guard limiter.shouldAddSpanLink(currentCount: span.links.count - internalCount) else {
            throw EmbraceOTelError.spanLinkLimitReached("Links limit reached for span \(span.name)")
        }

        return EmbraceSpanLink(
            spanId: spanId,
            traceId: traceId,
            attributes: sanitizer.sanitizeSpanEventAttributes(attributes)
        )
    }

    func validateAttribute(
        for span: EmbraceSpan,
        key: String,
        value: String?,
        internalCount: Int,
        isInternal: Bool
    ) throws -> (String, String?) {

        // no limits when removing a key or if the attribute is internal
        guard let value, !isInternal else {
            return (key, value)
        }

        let finalKey = sanitizer.sanitizeAttributeKey(key)
        let finalValue = sanitizer.sanitizeAttributeValue(value)

        return (finalKey, finalValue)
    }
}
