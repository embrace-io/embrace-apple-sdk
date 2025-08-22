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
public class EmbraceOTelSignalsHandler: NSObject, OTelSignalsHandler {

    private let storage: EmbraceStorage?
    private let sessionController: SessionController?
    private let logController: LogController?
    private let bridge: EmbraceOTelSignalBridge

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
        bridge: EmbraceOTelSignalBridge = DefaultOTelSignalBridge()
    ) {
        self.storage = storage
        self.sessionController = sessionController
        self.logController = logController
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
    /// - Throws: A `EmbraceOTelError.spanLimitReached` if the limit has been reached for the given span type.
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
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
    ) throws -> EmbraceSpan {

        // add embrace specific attributes
        var attributes = attributes
        attributes.setEmbraceType(type)
        attributes.setEmbraceSessionId(sessionController?.currentSession?.id)

        // create span context
        let context = bridge.startSpan(
            name: name,
            parentSpan: parentSpan,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes
        )

        // get auto termination code from parent if needed
        var code = autoTerminationCode
        if let parentSpan,
           code == nil {
            code = cache.safeValue.autoTerminationSpans[parentSpan.context.spanId]?.autoTerminationCode
        }

        // create span
        let span = DefaultEmbraceSpan(
            context: context,
            parentSpanId: parentSpan?.context.spanId,
            name: name,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            sessionId: sessionController?.currentSession?.id,
            processId: ProcessIdentifier.current,
            autoTerminationCode: code,
            delegate: self
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
    /// - Parameter event: The event to add.
    /// - Throws: A `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: A `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    public func addEvent(_ event: EmbraceSpanEvent) throws {

        guard let span = sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession("No active Embrace session!")
        }

        // TODO: Clean up
//        let eventsToAdd: [EmbraceSpanEvent] = Embrace.client?.spanEventsLimiter.applyLimits(events: [event]) ?? [event]
//        guard eventsToAdd.count > 0 else {
//            throw EmbraceOTelError.spanEventLimitReached("Limit reached for the span even type \"\(event.type.rawValue)\"!")
//        }
//
//        for event in eventsToAdd {
//            span.add(events: eventsToAdd)
//        }

//        span.add(events: [event])
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
    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .defaultStackTrace()
    ) {
        if let log = logController?.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior
        ) {
            bridge.createLog(log)
        }
    }
}

// MARK: Internal

extension EmbraceOTelSignalsHandler {
    func exportLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
    ) {
        if let log = logController?.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            send: false
        ) {
            bridge.createLog(log)
        }
    }
}

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
    
    func onSpanAttributeUpdated(_ span: EmbraceSpan, attributes: [String: String]) {
        storage?.setSpanAttributes(id: span.context.spanId, traceId: span.context.traceId, attributes: attributes)
    }
    
    func onSpanEnded(_ span: any EmbraceSpan, endTime: Date) {
        storage?.endSpan(id: span.context.spanId, traceId: span.context.traceId, endTime: endTime)
    }
}
