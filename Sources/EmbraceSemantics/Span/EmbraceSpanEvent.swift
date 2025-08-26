//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span event
@objc
open class EmbraceSpanEvent: NSObject {

    /// Name of the event
    @objc public let name: String

    /// Embrace specific type of the event
    @objc public let type: EmbraceType

    /// Date when the event occured
    @objc public let timestamp: Date

    /// Attributes of the event
    @objc public let attributes: [String: String]

    /// Creates a new `EmbraceSpanEvent`
    /// - Parameters:
    ///   - name: Name of the event
    ///   - type: Type of the event
    ///   - timestamp: Timestamp of the event
    ///   - attributes: Attributes of the event
    @objc package init(
        name: String,
        type: EmbraceType = .performance,
        timestamp: Date = Date(),
        attributes: [String : String] = [:]
    ) {
        self.name = name
        self.type = type
        self.timestamp = timestamp

        var finalAttributes = attributes
        finalAttributes[SpanSemantics.keyEmbraceType] = type.rawValue
        self.attributes = attributes
    }
}
