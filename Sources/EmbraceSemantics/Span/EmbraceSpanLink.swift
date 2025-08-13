//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// Represents an OTel span link
public protocol EmbraceSpanLink {
    
    /// Identifier of linked span
    var spanId: String { get }

    /// Trace identifier of the linked span
    var traceId: String { get }

    /// Attributes of the link
    var attributes: [String: String] { get }
}
