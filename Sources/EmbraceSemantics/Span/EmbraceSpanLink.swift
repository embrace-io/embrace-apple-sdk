//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// Represents an OTel span link
public protocol EmbraceSpanLink: EmbraceSignal {
    /// Identifier of linked span
    var spanId: String { get }

    /// Trace identifier of the linked span
    var traceId: String { get }
}
