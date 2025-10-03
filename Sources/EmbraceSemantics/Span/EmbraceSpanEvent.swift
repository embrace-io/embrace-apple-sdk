//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span event
open class EmbraceSpanEvent {

    /// Name of the event
    public let name: String

    /// Embrace specific type of the event, if any
    public let type: EmbraceType?

    /// Date when the event occured
    public let timestamp: Date

    /// Attributes of the event
    public let attributes: [String: String]

    /// Creates a new `EmbraceSpanEvent`
    /// - Parameters:
    ///   - name: Name of the event
    ///   - type: Type of the event
    ///   - timestamp: Timestamp of the event
    ///   - attributes: Attributes of the event
    package init(
        name: String,
        type: EmbraceType? = .performance,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
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
