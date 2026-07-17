//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceSemantics
#endif

/// Experiments and feature flags
extension EmbraceIO {

    /// Declares an experiment or feature flag the user is enrolled in.
    /// The state is tied to the process lifetime.
    ///
    /// - Note: No-op if an experiment with the same id was already started. Records are immutable
    ///         once set — an experiment's kind and variant cannot change after it is declared.
    /// - Parameters:
    ///   - id: Unique identifier of the experiment.
    ///   - kind: Whether the record is an experiment or a feature flag. Defaults to `.experiment`.
    ///   - variant: The variant the user was assigned, if any.
    ///   - startedAt: When the enrollment started. Defaults to now.
    public func startExperiment(
        id: String,
        kind: EmbraceExperimentKind = .experiment,
        variant: String? = nil,
        startedAt: Date? = nil
    ) {
        Embrace.client?.experiments.startExperiment(id: id, kind: kind, variant: variant, startedAt: startedAt)
    }

    /// Sets the end time of a previously started experiment.
    /// - Parameters:
    ///   - id: Unique identifier of the experiment.
    ///   - endedAt: When the enrollment ended. Defaults to now.
    public func endExperiment(id: String, endedAt: Date? = nil) {
        Embrace.client?.experiments.endExperiment(id: id, endedAt: endedAt)
    }
}
