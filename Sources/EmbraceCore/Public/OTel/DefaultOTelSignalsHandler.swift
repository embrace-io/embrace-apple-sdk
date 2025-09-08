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
public class DefaultOTelSignalsHandler {

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
        return try _createSpan(
            name: name,
            parentSpan: parentSpan,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            autoTerminationCode: autoTerminationCode,
            isInternal: false
        )
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
        try _addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            isInternal: false
        )
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
            stackTraceBehavior: stackTraceBehavior,
            isInternal: false
        )
    }

    // MARK: Internal
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
    let cache = EmbraceMutex(Cache())

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
}
