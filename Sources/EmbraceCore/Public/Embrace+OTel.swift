//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

extension Embrace: EmbraceOpenTelemetry {

    var otel: EmbraceOTel { EmbraceOTel() }

    /// - Parameters:
    ///    - instrumentationName: The name of the instrumentation library requesting the tracer.
    /// - Returns: An OpenTelemetry `Tracer` so callers can use interface directly.
    public func tracer(instrumentationName: String) -> Tracer {
        otel.tracer(instrumentationName: instrumentationName)
    }

    /// Returns an OpenTelemetry `SpanBuilder` that is using an Embrace `Tracer`.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - attributes: A dictionary of attributes to set on the span.
    ///    - autoTerminationCode: `SpanErrorCode` to be used to automatically close this span if the current session ends while the span is open.
    /// - Returns: An OpenTelemetry `SpanBuilder`.
    public func buildSpan(
        name: String,
        type: SpanType = .performance,
        attributes: [String: String] = [:],
        autoTerminationCode: SpanErrorCode? = nil
    ) -> SpanBuilder {
        guard let autoTerminationCode = autoTerminationCode else {
            return otel.buildSpan(name: name, type: type, attributes: attributes)
        }

        var attributes = attributes
        attributes[SpanSemantics.keyAutoTerminationCode] = autoTerminationCode.rawValue

        return otel.buildSpan(name: name, type: type, attributes: attributes)
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
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: SpanErrorCode?
    ) {
        let builder =
            otel
            .buildSpan(name: name, type: type, attributes: attributes)
            .setStartTime(time: startTime)

        if let parent = parent { builder.setParent(parent) }
        let span = builder.startSpan()

        events.forEach { event in
            span.addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
        }

        span.end(errorCode: errorCode, time: endTime)
    }

    /// Adds a list of `SpanEvent` objects to the current session span.
    /// If there is no current session, this event will be dropped.
    /// - Parameter events: An array of `SpanEvent` objects.
    public func add(events: [SpanEvent]) {
        guard events.isEmpty == false else {
            return
        }

        guard let span = sessionController.currentSessionSpan else {
            Embrace.logger.debug("\(#function) failed: No current session span")
            return
        }

        let eventsToAdd = spanEventsLimiter.applyLimits(events: events)
        guard eventsToAdd.isEmpty == false else {
            Embrace.logger.info("\(#function) failed: SpanEvents limit reached!")
            return
        }

        // console logs for breadcrumbs
        if Embrace.logger.level != .none && Embrace.logger.level.rawValue <= LogLevel.debug.rawValue {
            for event in eventsToAdd where event.isBreadcrumb {
                if let message = event.attributes[SpanEventSemantics.Breadcrumb.keyMessage]?.description {
                    Embrace.logger.debug("[Embrace Breadcrumb] \(message)")
                }
            }
        }

        span.add(events: eventsToAdd)
        flush(span)
    }

    /// Adds a single `SpanEvent` object to the current session span
    /// If there is no current session, this event will be dropped.
    /// - Parameter event: A `SpanEvent` object.
    public func add(event: SpanEvent) {
        add(events: [event])
    }

    /// Waits synchronously for all work to be completed
    @_spi(Private)
    public func waitForAllWork() {

        // This funcxtion used to use `asyncAndWait(::)`.
        // But it appears it crashes on iOS 16.4 sim.
        // Instead, just do what that function does under the hood.
        // Radar: FB21077492
        let group = DispatchGroup()

        processingQueue.async(group: group, flags: .assignCurrentContext) {}
        group.wait()

        guard let proc = EmbraceOTel.processor else { return }
        proc.processorQueue.async(group: group, flags: .assignCurrentContext) {}
        group.wait()
    }

    /// Flushes the given `ReadableSpan` compliant `Span` to disk.
    /// This is intended to save changes on long running spans.
    /// - Parameter span: A `Span` object that implements `ReadableSpan`.
    public func flush(_ span: Span) {
        processingQueue.async {
            if let span = span as? ReadableSpan {
                EmbraceOTel.processor?.flush(span: span)
            } else {
                Embrace.logger.debug("Tried to flush a non-ReadableSpan object")
            }
        }
    }

    /// Creates and adds a log for the current session span.
    /// - Parameters:
    ///   - message: Body of the log.
    ///   - severity: `LogSeverity` for the log.
    ///   - attributes: Attributes for the log.
    ///   - stackTraceBehavior: Defines if the stack trace information should be added to the log
    ///
    /// - Important: Only `warn` and `error` logs will have stacktraces.
    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        log(
            message,
            severity: severity,
            type: type,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior
        )
    }

    /// Creates and adds a log for the current session span.
    /// - Parameters:
    ///   - message: Body of the log.
    ///   - severity: `LogSeverity` for the log.
    ///   - timestamp: Timestamp for the log.
    ///   - attributes: Attributes for the log.
    ///   - stackTraceBehavior: Defines if the stack trace information should be added to the log
    ///
    /// - Important: Only `warn` and `error` logs will have stacktraces.
    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        self.logController.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: nil,
            attachmentId: nil,
            attachmentUrl: nil,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior,
            queue: processingQueue
        )
    }

    /// Creates and adds a log with the given data as an attachment for the current session span.
    /// The attachment will be hosted by Embrace and will be accessible through the dashboard.
    /// - Parameters:
    ///   - message: Body of the log.
    ///   - severity: `LogSeverity` for the log.
    ///   - timestamp: Timestamp for the log.
    ///   - attachment: Data of the attachment
    ///   - attributes: Attributes for the log.
    ///   - stackTraceBehavior: Defines if the stack trace information should be added to the log
    ///
    /// - Important: Only `warn` and `error` logs will have stacktraces.
    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date = Date(),
        attachment: Data,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        self.logController.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attachmentId: nil,
            attachmentUrl: nil,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior,
            queue: processingQueue
        )
    }

    /// Creates and adds a log with the given attachment info for the current session span.
    /// Use this method for attachments hosted outside of Embrace.
    /// - Parameters:
    ///   - message: Body of the log.
    ///   - severity: `LogSeverity` for the log.
    ///   - timestamp: Timestamp for the log.
    ///   - attachmentId: Identifier of the attachment
    ///   - attachmentUrl: URL to dowload the attachment data
    ///   - attributes: Attributes for the log.
    ///   - stackTraceBehavior: Defines if the stack trace information should be added to the log
    ///
    /// - Important: Only `warn` and `error` logs will have stacktraces.
    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date = Date(),
        attachmentId: String,
        attachmentUrl: URL,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        self.logController.createLog(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: nil,
            attachmentId: attachmentId,
            attachmentUrl: attachmentUrl,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior,
            queue: processingQueue
        )
    }
}

extension Embrace {  // MARK: Static methods

    /// Starts a span and executes the block. The span will be ended when the block returns.
    /// - Parameters:
    ///    - name: The name of the span.
    ///    - parent: The parent `Span`, if this span is a child.
    ///    - type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - attributes: A dictionary of attributes to set on the span.
    ///    - block: The block to execute, receives an an optional `Span` as an argument to allow block to append events or properties.
    /// - Returns: The result of the block.
    ///
    /// - Note: This method validates the presence of the Embrace client and will call the block with a nil span if the client is not present
    ///         It is recommended you use this method in order to be sure the block is run correctly.
    public static func recordSpan<T>(
        name: String,
        parent: Span? = nil,
        type: SpanType = .performance,
        attributes: [String: String] = [:],
        block: (Span?) throws -> T
    ) rethrows -> T {
        guard let embrace = Embrace.client else {
            // DEV: be sure to execute block if Embrace client is nil
            return try block(nil)
        }

        return try embrace.recordSpan(
            name: name,
            parent: parent,
            type: type,
            attributes: attributes,
            block: block
        )
    }
}

extension Embrace {  // MARK: Internal methods

    /// Starts a span and executes the block. The span will be ended when the block returns
    /// - Parameters:
    ///    - name: The name of the span.
    ///    -  parent: The parent span, if this span is a child.
    ///    -  type: The type of the span. Will be set as the `emb.type` attribute.
    ///    - attributes: A dictionary of attributes to set on the span.
    ///    - block: The block to execute, receives an an optional Span as an argument to allow block to append events or properties.
    /// - Returns: The result of the block.
    ///
    /// - Note: This method is not exposed publicly to prevent optional chaining from preventing the block from running.
    ///         It is recommended to use the static ``Embrace.recordSpan`` method.
    /// ```swift
    /// Embrace.client?.recordSpan(name: "example", type: .performance) {
    ///    // If Embrace.client is nil, this block will not execute
    ///    // Use `Embrace.recordSpan` to ensure the block is executed
    /// }
    /// ```
    func recordSpan<T>(
        name: String,
        parent: Span? = nil,
        type: SpanType,
        attributes: [String: String] = [:],
        block: (Span) throws -> T
    ) rethrows -> T {
        let builder = otel.buildSpan(name: name, type: type, attributes: attributes)
        if let parent = parent { builder.setParent(parent) }
        let span = builder.startSpan()

        let result = try block(span)

        span.end()
        return result
    }
}
