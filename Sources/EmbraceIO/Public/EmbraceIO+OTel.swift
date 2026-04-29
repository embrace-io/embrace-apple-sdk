//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// OTel signal generation
extension EmbraceIO {

    /// Creates a new span to be included in the current Embrace session.
    /// If the span limit has been reached or the SDK has not been set up, the span is dropped and a warning is logged.
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
    /// - Returns: The newly created `EmbraceSpan`, or `nil` if the span could not be created.
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
        attributes: EmbraceAttributes = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil
    ) -> EmbraceSpan? {
        guard let otel = Embrace.client?.otel else {
            return nil
        }
        return otel.createSpan(
            name: name,
            parentSpan: parentSpan,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            autoTerminationCode: autoTerminationCode
        )
    }

    /// Adds an event to the current Embrace session and returns the stored, sanitized event.
    /// If no session is active or the event limit has been reached, the event is dropped, a warning is logged, and `nil` is returned.
    /// - Parameters:
    ///   - name: Name of the event.
    ///   - type: Embrace specific type of the event, if any.
    ///   - timestamp: Timestamp of the event.
    ///   - attributes: Attributes of the event.
    /// - Returns: The sanitized event that was recorded, or `nil` if the SDK is not initialized, no session is active, or the limit was reached. The returned event may differ from your inputs because of name/attribute sanitization.
    @discardableResult
    public func addSessionEvent(
        name: String,
        type: EmbraceType? = nil,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) -> EmbraceSpanEvent? {
        return Embrace.client?.otel.addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes
        )
    }

    /// Adds the given event to the current Embrace session. Adapter that destructures into the flat-arg form.
    /// - Returns: The sanitized event that was recorded, or `nil` if the SDK is not initialized, no session is active, or the limit was reached. The returned event may differ from your inputs because of name/attribute sanitization.
    @discardableResult
    public func addSessionEvent(_ event: EmbraceSpanEvent) -> EmbraceSpanEvent? {
        return addSessionEvent(
            name: event.name,
            type: event.type,
            timestamp: event.timestamp,
            attributes: event.attributes
        )
    }

    /// Emits a new log.
    /// If the log limit has been reached for the current Embrace session, the log is dropped and a warning is logged.
    /// - Parameters:
    ///   - message: Message of the log.
    ///   - severity: Severity of the log.
    ///   - type: Type of the log.
    ///   - timestamp: Timestamp of the log.
    ///   - attachment: Attachment data for the log.
    ///   - attributes: Attributes of the log.
    ///   - stackTraceBehavior: Behavior that determines if a stack trace has to be generated for the log.
    public func log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: EmbraceAttributes = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default
    ) {
        Embrace.client?.otel.log(
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
