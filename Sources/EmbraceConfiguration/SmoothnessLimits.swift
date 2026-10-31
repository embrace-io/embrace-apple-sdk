//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// `SmoothnessLimits` manages the thresholds and limits applied to focal moments.
public struct SmoothnessLimits: Equatable {

    // MARK: - Defaults

    /// Default idle time (in seconds) after which a focal moment settles once all touches have lifted.
    public static let defaultIdleThreshold: TimeInterval = 0.1
    /// Default idle time (in seconds) after which a focal moment settles while any touch is held.
    public static let defaultHeldIdleThreshold: TimeInterval = 0.5
    /// Default maximum number of focal moment spans per session part.
    public static let defaultSpanLimit = 250

    // MARK: - Values

    /// Idle time (in seconds) after which a focal moment settles once all touches have lifted.
    public let idleThreshold: TimeInterval

    /// Idle time (in seconds) after which a focal moment settles while any touch is held.
    public let heldIdleThreshold: TimeInterval

    /// Maximum number of focal moment spans per session part. Zero emits none.
    public let spanLimit: Int

    /// A threshold that isn't finite and positive, or a negative span limit, falls back to its default.
    public init(
        idleThreshold: TimeInterval = SmoothnessLimits.defaultIdleThreshold,
        heldIdleThreshold: TimeInterval = SmoothnessLimits.defaultHeldIdleThreshold,
        spanLimit: Int = SmoothnessLimits.defaultSpanLimit
    ) {
        self.idleThreshold = SmoothnessLimits.sanitized(idleThreshold, fallback: SmoothnessLimits.defaultIdleThreshold)
        self.heldIdleThreshold = SmoothnessLimits.sanitized(heldIdleThreshold, fallback: SmoothnessLimits.defaultHeldIdleThreshold)
        self.spanLimit = spanLimit >= 0 ? spanLimit : SmoothnessLimits.defaultSpanLimit
    }

    private static func sanitized(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        value.isFinite && value > 0 ? value : fallback
    }
}
