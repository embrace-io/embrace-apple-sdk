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
    var attributes: [String: String] { get }

    /// Identifier of the active Embrace Session when the log was emitted, if any.
    var sessionId: EmbraceIdentifier? { get }

    /// Identifier of the process when the log was emitted.
    var processId: EmbraceIdentifier { get }

    /// Updates the status of the span
    func setStatus(_ status: EmbraceSpanStatus)

    /// Adds an event to the span
    /// Can fail if the event limit is reached.
    func addEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: [String: String]
    ) throws

    /// Adds a link to the span
    /// Can fail if the link limit is reached.
    func addLink(
        spanId: String,
        traceId: String,
        attributes: [String: String]
    ) throws

    /// Sets an attribute to the span
    /// Can fail if the attribute limit is reached.
    func setAttribute(key: String, value: String?) throws

    /// Ends the span with the given `endTime`
    func end(endTime: Date)

    /// Ends the span with `endTime = Date()`
    func end()
}

extension EmbraceSpan {

    /// Convenience method to add a span event at the current time.
    /// Can fail if the event limit is reached.
    public func addEvent(
        name: String,
        type: EmbraceType? = .performance,
        attributes: [String: String]
    ) throws {
        try addEvent(name: name, type: type, timestamp: Date(), attributes: attributes)
    }
}
