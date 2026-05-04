//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span signal.
public protocol EmbraceSpan {

    /// Name of the span
    var name: String { get }

    /// Identifier for the span
    var context: EmbraceSpanContext { get }

    /// Identifier for the span's parent
    var parentSpanId: String? { get }

    /// Embrace specific type of the span
    var type: EmbraceType { get }

    /// Status of the span
    var status: EmbraceSpanStatus { get }

    /// Date when the span was started
    var startTime: Date { get }

    /// Date when the span was ended, if any
    var endTime: Date? { get }

    /// Array of events in the span
    var events: [EmbraceSpanEvent] { get }

    /// Array of links in the span
    var links: [EmbraceSpanLink] { get }

    /// Attributes of the span
    var attributes: EmbraceAttributes { get }

    /// Identifier of the active Embrace Session when the log was emitted, if any.
    var sessionId: EmbraceIdentifier? { get }

    /// Identifier of the process when the log was emitted.
    var processId: EmbraceIdentifier { get }

    /// Updates the status of the span
    func setStatus(_ status: EmbraceSpanStatus)

    /// Adds an event to the span and returns the stored, sanitized event.
    ///
    /// - Important: The returned event is **not** the same instance as the inputs you provided.
    ///   Sanitization may have rewritten the name, truncated attribute keys/values, or capped
    ///   the attribute count. Use the returned value to inspect what was actually recorded.
    /// - Returns: The sanitized event that was appended to the span, or `nil` if the per-span
    ///   event limit was reached and the event was dropped (a warning is logged in that case).
    @discardableResult
    func addEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes
    ) -> EmbraceSpanEvent?

    /// Adds a link to the span and returns the stored, sanitized link.
    ///
    /// - Important: The returned link is **not** the same instance as the inputs you provided.
    ///   Sanitization may have truncated attribute keys/values or capped the attribute count.
    /// - Returns: The sanitized link that was appended to the span, or `nil` if the per-span
    ///   link limit was reached and the link was dropped (a warning is logged in that case).
    @discardableResult
    func addLink(
        spanId: String,
        traceId: String,
        attributes: EmbraceAttributes
    ) -> EmbraceSpanLink?

    /// Sets an attribute to the span
    /// Can fail if the attribute limit is reached.
    func setAttribute(key: String, value: EmbraceAttributeValue?) throws

    /// Ends the span with the given `endTime`
    func end(endTime: Date)

    /// Ends the span with `endTime = Date()`
    func end()
}

extension EmbraceSpan {

    /// Convenience method to add a span event at the current time.
    @discardableResult
    public func addEvent(
        name: String,
        type: EmbraceType? = .performance,
        attributes: EmbraceAttributes
    ) -> EmbraceSpanEvent? {
        return addEvent(name: name, type: type, timestamp: Date(), attributes: attributes)
    }

    /// Adds the given event to the span and returns the stored, sanitized event.
    ///
    /// - Important: The returned event is **not** the same instance as `event`. Sanitization
    ///   may have rewritten the name, truncated attribute keys/values, or capped the attribute
    ///   count. To inspect what was actually recorded, use the returned value rather than the
    ///   one you passed in — your `event` is left untouched.
    /// - Returns: The sanitized event that was appended to the span, or `nil` if the per-span
    ///   event limit was reached and the event was dropped.
    @discardableResult
    public func addEvent(_ event: EmbraceSpanEvent) -> EmbraceSpanEvent? {
        return addEvent(
            name: event.name,
            type: event.type,
            timestamp: event.timestamp,
            attributes: event.attributes
        )
    }

    /// Adds the given link to the span and returns the stored, sanitized link.
    ///
    /// - Important: The returned link is **not** the same instance as `link`. Sanitization
    ///   may have truncated attribute keys/values or capped the attribute count. Inspect the
    ///   returned value to see what was actually recorded; your `link` is left untouched.
    /// - Returns: The sanitized link that was appended to the span, or `nil` if the per-span
    ///   link limit was reached and the link was dropped.
    @discardableResult
    public func addLink(_ link: EmbraceSpanLink) -> EmbraceSpanLink? {
        return addLink(
            spanId: link.context.spanId,
            traceId: link.context.traceId,
            attributes: link.attributes
        )
    }
}
