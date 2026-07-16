//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

/// Holds all the experiments and feature flags declared during the process.
///
/// The state lives for the process lifetime and is the single source of truth. On every change
/// the full set is re-encoded into the `emb.experiments` wire format and persisted as a single
/// `.requiredResource` / `.process` metadata record (upserted, not one record per experiment).
/// `.requiredResource` is used because the storage layer already treats it as reserved: it is
/// never counted against user limits, never removed by user APIs or cleanup, and is written
/// without value truncation.
package class ExperimentsHandler {

    weak var storage: EmbraceStorage?

    private let queue: DispatchableQueue
    private var experiments: [String: Experiment] = [:]
    private var order: [String] = []

    init(
        storage: EmbraceStorage?,
        queue: DispatchableQueue = .with(label: "com.embrace.experimentsHandler")
    ) {
        self.storage = storage
        self.queue = queue
    }

    /// Declares an experiment or feature flag the user is enrolled in.
    /// No-op if an experiment with the same id was already started; records are immutable once set.
    /// - Parameters:
    ///   - id: Unique identifier of the experiment.
    ///   - kind: Whether the record is an experiment or a feature flag.
    ///   - variant: The variant the user was assigned, if any.
    ///   - startedAt: When the enrollment started. Defaults to now.
    package func startExperiment(
        id: String,
        kind: EmbraceExperimentKind = .experiment,
        variant: String? = nil,
        startedAt: Date? = nil
    ) {
        let start = startedAt ?? Date()
        queue.async { [weak self] in
            guard let self = self, self.experiments[id] == nil else {
                return
            }

            self.experiments[id] = Experiment(id: id, kind: kind, variant: variant, startedAt: start, endedAt: nil)
            self.order.append(id)
            self.persist()
        }
    }

    /// Sets the end time of a previously started experiment.
    /// This is the only way to set the end time. No-op if the id is unknown or already ended.
    /// - Parameters:
    ///   - id: Unique identifier of the experiment.
    ///   - endedAt: When the enrollment ended. Defaults to now.
    package func endExperiment(id: String, endedAt: Date? = nil) {
        let end = endedAt ?? Date()
        queue.async { [weak self] in
            guard let self = self,
                var experiment = self.experiments[id],
                experiment.endedAt == nil
            else {
                return
            }

            experiment.endedAt = end
            self.experiments[id] = experiment
            self.persist()
        }
    }

    /// Re-encodes the full set and upserts the single reserved metadata record.
    /// Must be called on `queue`.
    private func persist() {
        guard let storage = storage else {
            return
        }

        let ordered = order.compactMap { experiments[$0] }
        let encoded = ExperimentsEncoder.encode(ordered)

        storage.addMetadata(
            key: ExperimentsSemantics.key,
            value: encoded,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
    }
}
