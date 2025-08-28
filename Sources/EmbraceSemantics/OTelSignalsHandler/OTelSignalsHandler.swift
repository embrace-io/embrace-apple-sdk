//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Protocol used to generate OTel signals.
public protocol OTelSignalsHandler: AnyObject {

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
    func createSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: [String: String],
        autoTerminationCode: EmbraceSpanErrorCode?,
    ) throws -> EmbraceSpan

    /// Adds the given `EmbraceSpanEvent` to the current Embrace session.
    /// - Parameter event: The event to add.
    /// - Throws: A `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: A `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    func addSessionEvent(_ event: EmbraceSpanEvent) throws

    /// Emits a new log.
    /// - Parameters:
    ///   - message: Message of the log
    ///   - severity: Severity of the log
    ///   - type: Type of the log
    ///   - timestamp: Timestamp of the log
    ///   - attachment: Attachment data for the log
    ///   - attributes: Attributes of the log
    ///   - stackTraceBehavior: Behavior that detemines if a stack trace has to be generated for the log.
    func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: EmbraceLogAttachment?,
        attributes: [String: String],
        stackTraceBehavior: EmbraceStackTraceBehavior
    )
}

// MARK: Convenience
public extension OTelSignalsHandler {

    @discardableResult
    func createSpan(
        name: String,
        parentSpan: EmbraceSpan? = nil,
        type: EmbraceType = .performance,
        startTime: Date = Date(),
        endTime: Date? = nil,
        attributes: [String: String] = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
    ) throws -> EmbraceSpan {
        return try createSpan(
            name: name,
            parentSpan: parentSpan,
            type: type,
            status: .unset,
            startTime: startTime,
            endTime: endTime,
            events: [],
            links: [],
            attributes: attributes,
            autoTerminationCode: autoTerminationCode
        )
    }

    func log(
        _ message: String,
        severity: EmbraceLogSeverity = .info,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .defaultStackTrace()
    ) {
        log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: nil,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior
        )
    }
}
