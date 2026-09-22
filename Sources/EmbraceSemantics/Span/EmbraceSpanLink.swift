//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span link
public final class EmbraceSpanLink {

    /// Context of the linked span
    public let context: EmbraceSpanContext

    /// Attributes of the link
    public let attributes: EmbraceAttributes

    /// Creates a new `EmbraceSpanLink`
    /// - Parameters:
    ///   - context: Span context of the link
    ///   - attributes: Attributes of the link
    public init(context: EmbraceSpanContext, attributes: EmbraceAttributes = [:]) {
        self.context = context
        self.attributes = attributes
    }

    /// Creates a new `EmbraceSpanLink`
    /// - Parameters:
    ///   - spanId: Span identifier of the link
    ///   - traceId: Trace identifier of the link
    ///   - attributes: Attributes of the link
    public convenience init(spanId: String, traceId: String, attributes: EmbraceAttributes = [:]) {
        self.init(
            context: EmbraceSpanContext(spanId: spanId, traceId: traceId),
            attributes: attributes
        )
    }
}
