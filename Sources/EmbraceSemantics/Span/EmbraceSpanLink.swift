//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span link
@objc
public class EmbraceSpanLink: NSObject {

    /// Identifier of linked span
    @objc public let spanId: String

    /// Trace identifier of the linked span
    @objc public let traceId: String

    /// Attributes of the link
    @objc public let attributes: [String: String]

    /// Creates a new `EmbraceSpanLink`
    /// - Parameters:
    ///   - spanId: Span identifier of the link
    ///   - traceId: Trace identifier of the link
    ///   - attributes: Attributes of the link
    @objc public init(spanId: String, traceId: String, attributes: [String : String] = [:]) {
        self.spanId = spanId
        self.traceId = traceId
        self.attributes = attributes
    }
}
