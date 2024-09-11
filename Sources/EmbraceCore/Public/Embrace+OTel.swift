//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk

extension Embrace: EmbraceOpenTelemetry {
    private var exporter: SpanExporter {
        StorageSpanExporter(
            options: .init(storage: storage),
            logger: Embrace.logger
        )
    }

    private var otel: EmbraceOTel { EmbraceOTel() }

    /// - Parameters:
    ///     - instrumentationName: The name of the instrumentation library requesting the tracer.
    /// - Returns: An OpenTelemetry Tracer so callers can use interface directly
    public func tracer(instrumentationName: String) -> Tracer {
        otel.tracer(instrumentationName: instrumentationName)
    }

    /// Returns an OpenTelemetry SpanBuilder that is using an Embrace Tracer
    /// - Parameters:
    ///     - name: The name of the span
    ///     - type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    /// - Returns: An OpenTelemetry SpanBuilder
    public func buildSpan(
        name: String,
        type: SpanType = .performance,
        attributes: [String: String] = [:]
    ) -> SpanBuilder {
        otel.buildSpan(name: name, type: type, attributes: attributes)
    }

    /// Record a span after the fact
    /// - Parameters
    ///     - name: The name of the span
    ///     - type: The Embrace SpanType to mark this span. Defaults to `performance`
    ///     - parent: The parent span, if this span is a child
    ///     - startTime: The start time of the span
    ///     - endTime: The end time of the span
    ///     - attributes: A dictionary of attributes to set on the span. Defaults to an empty dictionary
    ///     - events: An array of events to add to the span. Defaults to an empty array
    ///     - errorCode: The error code of the span. Defaults to `noError`
    public func recordCompletedSpan(
        name: String,
        type: SpanType,
        parent: Span?,
        startTime: Date,
        endTime: Date,
        attributes: [String: String],
        events: [RecordingSpanEvent],
        errorCode: ErrorCode?
    ) {
        let builder = otel
            .buildSpan(name: name, type: type, attributes: attributes)
            .setStartTime(time: startTime)

        if let parent = parent { builder.setParent(parent) }
        let span = builder.startSpan()

        events.forEach { event in
            span.addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
        }

        span.end(errorCode: errorCode, time: endTime)
    }

    /// Adds a list of SpanEvent objects to the current session span
    /// If there is no current session, this event will be dropped
    /// - Parameter events: An array of SpanEvent objects
    public func add(events: [SpanEvent]) {
        guard let span = sessionController.currentSessionSpan else {
            Embrace.logger.debug("\(#function) failed: No current session span")
            return
        }

        span.add(events: events)

        flush(span)
    }

    /// Adds a single SpanEvent object to the current session span
    /// If there is no current session, this event will be dropped
    /// - Parameter event: A SpanEvent object
    public func add(event: SpanEvent) {
        add(events: [event])
    }

    /// Flushes the given ReadableSpan compliant Span to disk
    /// This is intended to save changes on long running spans.
    /// - Parameter span: A `Span` object that implements `ReadableSpan`
    public func flush(_ span: Span) {
        if let span = span as? ReadableSpan {
            _ = exporter.export(spans: [span.toSpanData()])
        } else {
            Embrace.logger.debug("Tried to flush a non-ReadableSpan object")
        }
    }

    /// Creates and adds a log for the current session span
    /// - Parameters:
    ///   - message: Body of the log
    ///   - severity: `LogSeverity` for the log
    ///   - attributes: Attributes for the log
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

    /// Creates and adds a log for the current session span
    /// - Parameters:
    ///   - message: Body of the log
    ///   - severity: `LogSeverity` for the log
    ///   - timestamp: Timestamp for the log
    ///   - attributes: Attributes for the log
    public func log(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        let attributesBuilder = EmbraceLogAttributesBuilder(
            storage: storage,
            sessionControllable: sessionController,
            initialAttributes: attributes
        )

        /*
         If we want to keep this method cleaner, we could move this logcto `EmbraceLogAttributesBuilder`
         However that would cause to always add a frame to the stacktrace.
         */
        if stackTraceBehavior == .default && (severity == .warn || severity == .error) {
            var stackTrace: [String] = Thread.callStackSymbols
            attributesBuilder.addStackTrace(stackTrace)
        }

        let finalAttributes = attributesBuilder
            .addLogType(type)
            .addApplicationState()
            .addApplicationProperties()
            .addSessionIdentifier()
            .build()

        otel.log(message, severity: severity, attributes: finalAttributes)
    }
}

extension Embrace { // MARK: Static methods

    /// Starts a span and executes the block. The span will be ended when the block returns
    /// - Parameters
    ///     - name: The name of the span
    ///     -  parent: The parent span, if this span is a child
    ///     -  type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    ///     - block: The block to execute, receives an an optional Span as an argument to allow block to append events or properties
    /// - Returns  The result of the block
    ///
    /// - Note This method validates the presence of the Embrace client and will call the block with a nil span if the client is not present
    ///                 It is recommended you use this method in order to be sure the block is run correctly.
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

extension Embrace { // MARK: Internal methods

    /// Starts a span and executes the block. The span will be ended when the block returns
    /// - Parameters
    ///     - name: The name of the span
    ///     -  parent: The parent span, if this span is a child
    ///     -  type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    ///     - block: The block to execute, receives an an optional Span as an argument to allow block to append events or properties
    /// - Returns  The result of the block
    ///
    ///
    /// **Note** This method is not exposed publicly to prevent optional chaining from preventing the block from running.
    /// It is recommended to use the static ``Embrace.recordSpan`` method.
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
