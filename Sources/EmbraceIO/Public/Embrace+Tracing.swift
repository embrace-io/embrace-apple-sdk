//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel

extension Embrace: EmbraceOpenTelemetry {

    private var otel: EmbraceOTel { EmbraceOTel() }

    /// Returns an OpenTelemetry SpanBuilder that is using an Embrace Tracer
    /// - Parameters:
    ///     - name: The name of the span
    ///     - type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    /// - Returns: An OpenTelemetry SpanBuilder
    public func buildSpan(name: String, type: SpanType, attributes: [String: String] = [:]) -> SpanBuilder {
        otel.buildSpan(name: name, type: type, attributes: attributes)
    }

    /// Starts a span and executes the block. The span will be ended when the block returns
    /// - Parameters
    ///     - name: The name of the span
    ///     -  parent: The parent span, if this span is a child
    ///     -  type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    ///     - block: The block to execute
    /// - Returns  The result of the block
    public func recordSpan<T>(
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

    /// Record a span after the fact
    /// - Parameters
    ///     - name: The name of the span
    ///     - parent: The parent span, if this span is a child
    ///     - startTime: The start time of the span
    ///     - endTime: The end time of the span
    ///     - attributes: A dictionary of attributes to set on the span. Defaults to an empty dictionary
    ///     - events: An array of events to add to the span. Defaults to an empty array
    ///     - errorCode: The error code of the span. Defaults to `noError`
    public func recordCompletedSpan(
        name: String,
        parent: Span? = nil,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:],
        events: [RecordingSpanEvent] = [],
        errorCode: ErrorCode? = nil
    ) {

        let builder = otel
            .buildSpan(name: name, type: .performance, attributes: attributes)
            .setStartTime(time: startTime)
        if let parent = parent { builder.setParent(parent) }
        let span = builder.startSpan()

        events.forEach { event in
            span.addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
        }

        span.end(time: endTime)
    }

    /// Adds a list of SpanEvent objects to the current session span
    /// If there is no current session, this event will be dropped
    /// - Parameter events: An array of SpanEvent objects
    public func add(events: [SpanEvent]) {
        sessionController.currentSessionSpan?.add(events: events)
    }

    /// Adds a single SpanEvent object to the current session span
    /// If there is no current session, this event will be dropped
    /// - Parameter event: A SpanEvent object
    public func add(event: SpanEvent) {
        add(events: [event])
    }

}
