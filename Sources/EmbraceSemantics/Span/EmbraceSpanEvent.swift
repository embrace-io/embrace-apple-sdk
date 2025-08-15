//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span event
@objc
public class EmbraceSpanEvent: NSObject {

    /// Name of the event
    @objc public let name: String

    /// Date when the event occured
    @objc public let timestamp: Date

    /// Attributes of the event
    @objc public let attributes: [String: String]

    /// Creates a new `EmbraceSpanEvent`
    /// - Parameters:
    ///   - name: Name of the event
    ///   - timestamp: Timestamp of the event
    ///   - attributes: Attributes of the event
    @objc public init(name: String, timestamp: Date = Date(), attributes: [String : String] = [:]) {
        self.name = name
        self.timestamp = timestamp
        self.attributes = attributes
    }
}
