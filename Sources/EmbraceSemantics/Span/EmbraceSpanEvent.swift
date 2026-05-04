//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span event.
///
/// - Note: When `type` is non-nil, the initializer stamps a `SpanEventSemantics.keyEmbraceType`
///   entry into the resulting `attributes` dictionary. Reading `event.attributes` therefore
///   returns your input merged with that one Embrace-specific key — it is not a verbatim copy
///   of what you passed in. The original dictionary you supplied is never mutated; this
///   stamping happens during construction of the new event instance.
public final class EmbraceSpanEvent {

    /// Name of the event
    public let name: String

    /// Embrace specific type of the event, if any
    public let type: EmbraceType?

    /// Date when the event occured
    public let timestamp: Date

    /// Attributes of the event
    public let attributes: EmbraceAttributes

    /// Creates a new `EmbraceSpanEvent`
    /// - Parameters:
    ///   - name: Name of the event
    ///   - type: Type of the event
    ///   - timestamp: Timestamp of the event
    ///   - attributes: Attributes of the event
    public init(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) {
        self.name = name
        self.type = type
        self.timestamp = timestamp

        if let type {
            var finalAttributes = attributes
            finalAttributes[SpanEventSemantics.keyEmbraceType] = type.rawValue
            self.attributes = finalAttributes
        } else {
            self.attributes = attributes
        }
    }
}
