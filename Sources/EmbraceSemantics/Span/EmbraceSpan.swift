//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span signal.
public protocol EmbraceSpan: EmbraceSignal {

    /// Identifier for the span
    var id: String { get }

    /// Trace identifier for the span
    var traceId: String { get }

    /// Identifier for the span's parent
    var parentSpanId: String? { get }

    /// Name of the span
    var name: String { get }

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

    /// Identifier of the active Embrace Session when the log was emitted, if any.
    var sessionId: EmbraceIdentifier? { get }

    /// Identifier of the process when the log was emitted.
    var processId: EmbraceIdentifier { get }

    /// Updates the status of the span
    func setStatus(_ status: EmbraceSpanStatus)

    /// Adds an event to the span
    func addEvent(_ event: EmbraceSpanEvent)

    /// Adds a link to the span
    func addLink(_ link: EmbraceSpanLink)

    /// Ends the span with the given `endTime`
    func end(endTime: Date)

    /// Ends the span with `endTime = Date()`
    func end()
}
