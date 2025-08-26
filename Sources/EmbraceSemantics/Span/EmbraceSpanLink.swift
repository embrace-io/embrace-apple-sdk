//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span link
@objc
public class EmbraceSpanLink: NSObject {

    /// Context of the linked span
    @objc public let context: EmbraceSpanContext

    /// Attributes of the link
    @objc public let attributes: [String: String]

    /// Creates a new `EmbraceSpanLink`
    /// - Parameters:
    ///   - context: Span context of the link
    ///   - attributes: Attributes of the link
    @objc package init(context: EmbraceSpanContext, attributes: [String : String] = [:]) {
        self.context = context
        self.attributes = attributes
    }

    /// Creates a new `EmbraceSpanLink`
    /// - Parameters:
    ///   - spanId: Span identifier of the link
    ///   - traceId: Trace identifier of the link
    ///   - attributes: Attributes of the link
    @objc package convenience init(spanId: String, traceId: String, attributes: [String : String] = [:]) {
        self.init(
            context: EmbraceSpanContext(spanId: spanId, traceId: traceId),
            attributes: attributes
        )
    }
}
