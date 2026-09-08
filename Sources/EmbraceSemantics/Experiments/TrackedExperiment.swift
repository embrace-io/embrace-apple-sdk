//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// An experiment a user is enrolled in.
///
/// Records are identified by their `id` combined with their kind, so an experiment and a feature flag
/// may share the same `id` and remain independent of each other.
public struct TrackedExperiment {

    /// Identifier of the experiment.
    ///
    /// Surrounding whitespace is removed. An `id` that is empty once trimmed, or longer than the
    /// allowed maximum, causes the entry to be dropped. Identifiers are never truncated, as a
    /// truncated identifier would refer to a different experiment.
    public let id: String

    /// Variant the user was assigned to, if any.
    ///
    /// `nil`, an empty string and a whitespace-only string are all equivalent and produce the same
    /// result. Surrounding whitespace is removed. A variant longer than the allowed maximum causes
    /// the whole entry to be dropped.
    public let variant: String?

    /// Moment the enrollment started.
    ///
    /// `nil` means the moment the tracking call is made.
    public let startedAt: Date?

    public init(id: String, variant: String? = nil, startedAt: Date? = nil) {
        self.id = id
        self.variant = variant
        self.startedAt = startedAt
    }
}
