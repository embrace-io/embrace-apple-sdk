//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceSemantics
#endif

/// Experiments
///
/// Declaring the experiments a user is enrolled in lets the sessions, logs, crashes and performance
/// data produced by this process be segmented and compared by experiment and variant.
///
/// The declared state belongs to the process, not to a single session: it is held for as long as the
/// app runs and is attached to everything the SDK reports during that time. It is not persisted
/// across launches, so it has to be declared again on every start.
///
/// A record is identified by its kind together with its id, so an experiment and a feature flag may
/// share an id and stay independent of each other.
///
/// - Note: These methods do nothing until the SDK has been set up. Calls made before
///         `EmbraceIO.setup(options:)` are ignored rather than queued.
extension EmbraceIO {

    /// Declares a list of experiments the user is enrolled in.
    ///
    /// The first call for a given id fixes its variant and start time. Later calls for that same id
    /// change nothing, whatever they pass, including after the experiment has been untracked.
    ///
    /// Entries are applied in order. An invalid entry is dropped on its own without affecting the
    /// rest of the list: an id that is empty once trimmed is dropped, and so is an entry whose id or
    /// variant is over the allowed length. Values are never truncated, since a truncated id would
    /// refer to a different experiment. Duplicate ids within one call resolve to the first one.
    /// An empty list does nothing.
    ///
    /// An entry whose start time cannot be represented as a timestamp is dropped the same way, with
    /// no error and nothing logged. That covers a `Date` built from a value such as `nan` or
    /// `infinity`, and any date further than roughly 292 years from 1970.
    ///
    /// - Parameter experiments: The experiments to track.
    public func trackExperiments(_ experiments: [TrackedExperiment]) {
        Embrace.client?.experiments.trackExperiments(experiments)
    }

    /// Declares a single experiment the user is enrolled in.
    ///
    /// Equivalent to calling `trackExperiments(_:)` with one entry.
    ///
    /// - Parameters:
    ///   - id: Identifier of the experiment. Surrounding whitespace is removed.
    ///   - variant: Variant the user was assigned to. `nil`, an empty string and a whitespace-only
    ///              string are all equivalent.
    ///   - startedAt: When the enrollment started. Defaults to the moment of the call. A date that
    ///                cannot be represented as a timestamp is not usable, and the whole call is
    ///                ignored.
    public func trackExperiment(id: String, variant: String? = nil, startedAt: Date? = nil) {
        trackExperiments([TrackedExperiment(id: id, variant: variant, startedAt: startedAt)])
    }

    /// Marks a list of experiments as ended.
    ///
    /// The records stay in the reported data with their end time recorded, rather than disappearing,
    /// so the end is known rather than inferred. Only the first call for a given id takes effect.
    /// Ids that were never tracked, or that belong to a feature flag rather than an experiment, are
    /// ignored.
    ///
    /// The end time applies to every id in the call, so one that cannot be represented as a
    /// timestamp — a `Date` built from a value such as `nan` or `infinity`, or a date further than
    /// roughly 292 years from 1970 — makes the whole call do nothing, with no error and nothing
    /// logged.
    ///
    /// - Parameters:
    ///   - ids: Identifiers of the experiments to end.
    ///   - endedAt: When the enrollments ended. Defaults to the moment of the call.
    public func untrackExperiments(ids: [String], endedAt: Date? = nil) {
        Embrace.client?.experiments.untrackExperiments(ids: ids, endedAt: endedAt)
    }

    /// Marks a single experiment as ended.
    ///
    /// Equivalent to calling `untrackExperiments(ids:endedAt:)` with one id. This only ends the
    /// experiment: a feature flag sharing the same id is left untouched.
    ///
    /// - Parameters:
    ///   - id: Identifier of the experiment to end.
    ///   - endedAt: When the enrollment ended. Defaults to the moment of the call. A date that
    ///              cannot be represented as a timestamp is not usable, and the whole call is
    ///              ignored.
    public func untrackExperiment(id: String, endedAt: Date? = nil) {
        untrackExperiments(ids: [id], endedAt: endedAt)
    }
}

/// Feature flags
///
/// Feature flags are recorded exactly like experiments and follow the same rules. They are kept as a
/// separate kind so they can be presented as a distinct experience.
extension EmbraceIO {

    /// Declares a list of feature flags the user is exposed to.
    ///
    /// The first call for a given id fixes its variant and start time. Later calls for that same id
    /// change nothing, whatever they pass, including after the flag has been untracked.
    ///
    /// Entries are applied in order. An invalid entry is dropped on its own without affecting the
    /// rest of the list: an id that is empty once trimmed is dropped, and so is an entry whose id or
    /// variant is over the allowed length. Values are never truncated, since a truncated id would
    /// refer to a different flag. Duplicate ids within one call resolve to the first one.
    /// An empty list does nothing.
    ///
    /// An entry whose start time cannot be represented as a timestamp is dropped the same way, with
    /// no error and nothing logged. That covers a `Date` built from a value such as `nan` or
    /// `infinity`, and any date further than roughly 292 years from 1970.
    ///
    /// - Parameter flags: The feature flags to track.
    public func trackFeatureFlags(_ flags: [TrackedFeatureFlag]) {
        Embrace.client?.experiments.trackFeatureFlags(flags)
    }

    /// Declares a single feature flag the user is exposed to.
    ///
    /// Equivalent to calling `trackFeatureFlags(_:)` with one entry.
    ///
    /// - Parameters:
    ///   - id: Identifier of the feature flag. Surrounding whitespace is removed.
    ///   - variant: Variant the user was assigned to. `nil`, an empty string and a whitespace-only
    ///              string are all equivalent.
    ///   - startedAt: When the exposure started. Defaults to the moment of the call. A date that
    ///                cannot be represented as a timestamp is not usable, and the whole call is
    ///                ignored.
    public func trackFeatureFlag(id: String, variant: String? = nil, startedAt: Date? = nil) {
        trackFeatureFlags([TrackedFeatureFlag(id: id, variant: variant, startedAt: startedAt)])
    }

    /// Marks a list of feature flags as ended.
    ///
    /// The records stay in the reported data with their end time recorded, rather than disappearing,
    /// so the end is known rather than inferred. Only the first call for a given id takes effect.
    /// Ids that were never tracked, or that belong to an experiment rather than a feature flag, are
    /// ignored.
    ///
    /// The end time applies to every id in the call, so one that cannot be represented as a
    /// timestamp — a `Date` built from a value such as `nan` or `infinity`, or a date further than
    /// roughly 292 years from 1970 — makes the whole call do nothing, with no error and nothing
    /// logged.
    ///
    /// - Parameters:
    ///   - ids: Identifiers of the feature flags to end.
    ///   - endedAt: When the exposures ended. Defaults to the moment of the call.
    public func untrackFeatureFlags(ids: [String], endedAt: Date? = nil) {
        Embrace.client?.experiments.untrackFeatureFlags(ids: ids, endedAt: endedAt)
    }

    /// Marks a single feature flag as ended.
    ///
    /// Equivalent to calling `untrackFeatureFlags(ids:endedAt:)` with one id. This only ends the
    /// feature flag: an experiment sharing the same id is left untouched.
    ///
    /// - Parameters:
    ///   - id: Identifier of the feature flag to end.
    ///   - endedAt: When the exposure ended. Defaults to the moment of the call. A date that
    ///              cannot be represented as a timestamp is not usable, and the whole call is
    ///              ignored.
    public func untrackFeatureFlag(id: String, endedAt: Date? = nil) {
        untrackFeatureFlags(ids: [id], endedAt: endedAt)
    }
}
