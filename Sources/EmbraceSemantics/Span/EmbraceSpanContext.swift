//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents the context for a `EmbraceSpan`.
public class EmbraceSpanContext {

    /// Span idenfifier
    public let spanId: String

    /// Trace identifier
    public let traceId: String

    /// Creates a new `EmbraceSpanContext`.
    /// - Parameters:
    ///   - spanId: Span identifier of the context
    ///   - traceId: Trace identifier of the context
    package init(spanId: String, traceId: String) {
        self.spanId = spanId
        self.traceId = traceId
    }
}
