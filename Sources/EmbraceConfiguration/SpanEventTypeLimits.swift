//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// `SpanEventTypeLimits` manages limits for span events included in the session span.
public struct SpanEventTypeLimits: Equatable {

    /// Maximum number of breadcrumb span events included in the session span.
    public let breadcrumb: UInt

    /// Maximum number of tap span events included in the session span.
    public let tap: UInt

    /// Creates a new `SpanEventTypeLimits` with the given per-type limits.
    public init(breadcrumb: UInt = 100, tap: UInt = 80) {
        self.breadcrumb = breadcrumb
        self.tap = tap
    }

    public static func == (lhs: SpanEventTypeLimits, rhs: SpanEventTypeLimits) -> Bool {
        return lhs.breadcrumb == rhs.breadcrumb && lhs.tap == rhs.tap
    }
}
