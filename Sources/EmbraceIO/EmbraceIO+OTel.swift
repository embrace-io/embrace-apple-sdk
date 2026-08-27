//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceOTelInternal
#endif

/// OTel spans
extension EmbraceIO {

    /// Returns an OpenTelemetry `SpanBuilder` that is using an Embrace `Tracer`.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - attributes: A dictionary of attributes to set on the span.
    ///    - autoTerminationCode: `SpanErrorCode` to be used to automatically close this span if the current session ends while the span is open.
    /// - Returns: An OpenTelemetry `SpanBuilder` (or `nil` if the Embrace SDK was not initialized yet).
    public func buildSpan(
        name: String,
        type: SpanType = .performance,
        attributes: [String: String] = [:],
        autoTerminationCode: SpanErrorCode? = nil
    ) -> SpanBuilder? {
        return Embrace.client?.buildSpan(
            name: name,
            type: type,
            attributes: attributes,
            autoTerminationCode: autoTerminationCode
        )
    }

    /// Record a span after the fact
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - type: The Embrace `SpanType` to mark this span. Defaults to `performance`.
    ///    - parent: The parent `Span`, if this span is a child.
    ///    - startTime: The start time of the span.
    ///    - endTime: The end time of the span.
    ///    - attributes: A dictionary of attributes to set on the span. Defaults to an empty dictionary.
    ///    - events: An array of events to add to the span. Defaults to an empty array.
    ///    - errorCode: The error code of the span. Defaults to `noError`.
    public func recordCompletedSpan(
        name: String,
        type: SpanType = .performance,
        parent: Span? = nil,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:],
        events: [RecordingSpanEvent] = [],
        errorCode: SpanErrorCode? = nil
    ) {
        Embrace.client?.recordCompletedSpan(
            name: name,
            type: type,
            parent: parent,
            startTime: startTime,
            endTime: endTime,
            attributes: attributes,
            events: events,
            errorCode: errorCode
        )
    }

    /// Flushes the given `ReadableSpan` compliant `Span` to disk.
    /// This is intended to save changes on long running spans.
    /// - Parameter span: A `Span` object that implements `ReadableSpan`.
    public func flush(_ span: Span) {
        Embrace.client?.flush(span)
    }
}

// OTel span events
extension EmbraceIO {
    /// Adds a list of `SpanEvent` objects to the current session span.
    /// If there is no current session, this event will be dropped.
    /// - Parameter events: An array of `SpanEvent` objects.
    public func add(events: [SpanEvent]) {
        Embrace.client?.add(events: events)
    }

    /// Adds a single `SpanEvent` object to the current session span
    /// If there is no current session, this event will be dropped.
    /// - Parameter event: A `SpanEvent` object.
    public func add(event: SpanEvent) {
        add(events: [event])
    }
}

// OTel logs
extension EmbraceIO {

    /// Emits a new log.
    /// - Parameters:
    ///   - message: Message of the log
    ///   - severity: Severity of the log
    ///   - type: Type of the log
    ///   - timestamp: Timestamp of the log
    ///   - attachment: Attachment for the log
    ///   - attributes: Attributes of the log
    ///   - stackTraceBehavior: Behavior that detemines if a stack trace has to be generated for the log.
    /// - Throws: `EmbraceOTelError.logLimitReached` if the log limit has been reached for the current Embrace session.
    public func log(
        _ message: String,
        severity: LogSeverity = .info,
        type: LogType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) throws {
        if let attachment {
            if let attachmentData = attachment.data {
                Embrace.client?.log(
                    message,
                    severity: severity,
                    type: type,
                    timestamp: timestamp,
                    attachment: attachmentData,
                    attributes: attributes,
                    stackTraceBehavior: stackTraceBehavior
                )
            } else if let attachmentUrl = attachment.url {
                Embrace.client?.log(
                    message,
                    severity: severity,
                    type: type,
                    timestamp: timestamp,
                    attachmentId: attachment.id,
                    attachmentUrl: attachmentUrl,
                    attributes: attributes,
                    stackTraceBehavior: stackTraceBehavior
                )
            }
        } else {
            Embrace.client?.log(
                message,
                severity: severity,
                type: type,
                timestamp: timestamp,
                attributes: attributes,
                stackTraceBehavior: stackTraceBehavior
            )
        }
    }
}
