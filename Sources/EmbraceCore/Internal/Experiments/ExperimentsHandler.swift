//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if canImport(UIKit) && !os(watchOS)
    import UIKit
#endif
#if os(watchOS)
    import WatchKit
#endif
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import EmbraceStorageInternal
#endif

extension Notification.Name {
    /// Posted whenever the tracked experiments change, carrying the new encoded value as the object.
    /// Lets the current session span stay up to date without the handler knowing about sessions.
    static let embraceExperimentsChanged = Notification.Name("embrace.experiments.changed")
}

/// Holds every experiment and feature flag tracked during the current process.
///
/// The records live in memory for the life of the process, and their encoded form is cached for the
/// callers that report it: the session span and every log. It is also mirrored into storage as a
/// required resource, purely so a later process can read back the value of the process that produced
/// it — which is what lets a recovered crash report carry the right one. That storage record is not
/// meant to be reported as a resource, so `ResourcePayload` excludes the key when it builds the
/// resource block of a payload.
///
/// Reporting the value is debounced. Tracking a batch of flags one call at a time would otherwise
/// mirror the value once per call, and each of those does a keyed CoreData fetch plus a session span
/// upsert. See ``schedulePersist()`` for what the debounce costs.
package class ExperimentsHandler {

    private struct State {
        /// Insertion order is the order records appear in the encoded value.
        var records: [ExperimentRecord] = []
        /// Position of each record in `records`, for constant time existence checks.
        var index: [ExperimentRecordKey: Int] = [:]
        /// Cached encoded value, rejoined from the records' own encoded forms only when they change.
        var encoded: String?
        var limits: ExperimentsLimits
        /// The debounced write waiting to run, if any. Replaced on every change.
        var pendingPersist: DispatchWorkItem?
        /// When the burst of changes now waiting to be reported began, for the max wait.
        var firstPendingChange: Date?
    }

    /// How long the records have to stay unchanged before the value is reported.
    package static let defaultPersistDebounceInterval: TimeInterval = 0.2

    /// Longest the reporting of a change may be deferred, however many changes keep arriving.
    package static let defaultMaxPersistDelay: TimeInterval = 1.0

    private let state: EmbraceMutex<State>

    private weak var storage: EmbraceStorage?
    private let notificationCenter: NotificationCenter
    private weak var logger: InternalLogger?

    private let persistQueue: DispatchQueue
    private let persistDebounceInterval: TimeInterval
    private let maxPersistDelay: TimeInterval

    package init(
        storage: EmbraceStorage?,
        experimentsLimits: ExperimentsLimits,
        configNotificationCenter: NotificationCenter,
        logger: InternalLogger? = Embrace.logger,
        persistDebounceInterval: TimeInterval = ExperimentsHandler.defaultPersistDebounceInterval,
        maxPersistDelay: TimeInterval = ExperimentsHandler.defaultMaxPersistDelay,
        persistQueue: DispatchQueue = DispatchQueue(label: "io.embrace.experiments.persist", qos: .utility)
    ) {
        self.storage = storage
        self.notificationCenter = configNotificationCenter
        self.logger = logger
        self.persistDebounceInterval = persistDebounceInterval
        self.maxPersistDelay = maxPersistDelay
        self.persistQueue = persistQueue
        self.state = EmbraceMutex(State(limits: experimentsLimits))

        notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: .embraceConfigUpdated,
            object: nil
        )

        addLifecycleObservers()
    }

    deinit {
        notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Current value

    /// The cached encoded value. Read whenever a log is created, so it never re-serializes and never
    /// touches storage.
    package var encodedExperiments: String? {
        state.withLock { $0.encoded }
    }

    // MARK: - Tracking

    package func trackExperiments(_ experiments: [TrackedExperiment]) {
        track(
            experiments.map { Entry(id: $0.id, variant: $0.variant, startedAt: $0.startedAt) },
            kind: .experiment
        )
    }

    package func trackFeatureFlags(_ flags: [TrackedFeatureFlag]) {
        track(
            flags.map { Entry(id: $0.id, variant: $0.variant, startedAt: $0.startedAt) },
            kind: .featureFlag
        )
    }

    package func untrackExperiments(ids: [String], endedAt: Date? = nil) {
        untrack(ids: ids, kind: .experiment, endedAt: endedAt)
    }

    package func untrackFeatureFlags(ids: [String], endedAt: Date? = nil) {
        untrack(ids: ids, kind: .featureFlag, endedAt: endedAt)
    }

    /// Kind-agnostic shape the two `track` entry points normalize to, so both kinds go through
    /// exactly the same validation and insertion logic.
    private struct Entry {
        let id: String
        let variant: String?
        let startedAt: Date?
    }

    private func track(_ entries: [Entry], kind: ExperimentKind) {
        // Sampled once so every entry in a call that omits its timestamp shares the same value.
        // This is what makes the single entry and bulk forms produce identical output.
        let now = Date()

        var droppedForCap = false
        var droppedEmptyId = false
        var droppedTooLong = false
        var didChange = false

        state.withLock { state in
            // Read under the same lock as the mutation, so a config update landing mid-call can't
            // apply two different limits to one batch.
            let limits = state.limits
            var changed = false

            for entry in entries {
                let id = entry.id.strippedForExperiments()
                guard !id.isEmpty else {
                    droppedEmptyId = true
                    continue
                }

                // The existence check runs before every other rejection. Tracking a record that is
                // already known is a no-op whatever it passes, and must stay silent even at the cap,
                // otherwise harmless repeat calls would be reported as drops.
                let key = ExperimentRecordKey(kind: kind, id: id)
                guard state.index[key] == nil else {
                    continue
                }

                // A caller-provided date can hold a value that no timestamp can express: `NaN`, an
                // infinity, or a date thousands of years away. Encoding one crashes, so the entry is
                // dropped on its own, quietly, leaving the rest of the list untouched.
                if let startedAt = entry.startedAt, !startedAt.isValid {
                    continue
                }

                // Over-limit values drop the whole entry and are never truncated: a truncated id is a
                // different id, and a truncated variant is a different variant.
                guard id.count <= limits.maxIdLength else {
                    droppedTooLong = true
                    continue
                }

                var variant = entry.variant?.strippedForExperiments()
                if variant?.isEmpty == true {
                    variant = nil
                }

                if let variant = variant, variant.count > limits.maxVariantLength {
                    droppedTooLong = true
                    continue
                }

                guard state.records.count < limits.maxCount else {
                    droppedForCap = true
                    continue
                }

                state.records.append(
                    ExperimentRecord(
                        kind: kind,
                        id: id,
                        variant: variant,
                        startedAt: entry.startedAt ?? now,
                        endedAt: nil
                    )
                )
                state.index[key] = state.records.count - 1
                changed = true
            }

            if changed {
                state.encoded = ExperimentsSerializer.serialize(state.records)
                didChange = true
            }
        }

        if droppedEmptyId {
            logger?.warning("Experiments with an empty id were dropped!")
        }

        if droppedTooLong {
            logger?.warning("Experiments with an id or variant over the length limit were dropped!")
        }

        if droppedForCap {
            logger?.warning("The limit of tracked experiments for this process was reached!")
        }

        // A bulk call rebuilds the value once and reports it once.
        if didChange {
            schedulePersist()
        }
    }

    private func untrack(ids: [String], kind: ExperimentKind, endedAt: Date?) {
        // The end time applies to every id in the call, so one that no timestamp can express — and
        // that would crash every record it is written to — discards the whole call rather than part
        // of it. Dropped quietly, like an unusable start time.
        if let endedAt = endedAt, !endedAt.isValid {
            return
        }

        let now = Date()
        var didChange = false

        state.withLock { state in
            var changed = false

            for rawId in ids {
                let id = rawId.strippedForExperiments()
                guard !id.isEmpty,
                    let position = state.index[ExperimentRecordKey(kind: kind, id: id)]
                else {
                    continue
                }

                // The first end time wins, mirroring the write-once rule for tracking.
                guard state.records[position].endedAt == nil else {
                    continue
                }

                state.records[position].end(at: endedAt ?? now)
                changed = true
            }

            if changed {
                state.encoded = ExperimentsSerializer.serialize(state.records)
                didChange = true
            }
        }

        // There is no cap check anywhere in this path. Ending a record has to keep working once the
        // record limit is reached, even though it makes the encoded value grow.
        if didChange {
            schedulePersist()
        }
    }

    // MARK: - Persistence

    /// Schedules the current value to be reported once the records stop changing.
    ///
    /// Tracking is bursty — a launch typically tracks several flags in a row — and every report costs
    /// a keyed CoreData fetch plus a session span upsert, so a burst is collapsed into one report
    /// instead of one per call. Two rules bound the wait:
    ///
    /// - the records must be unchanged for ``persistDebounceInterval`` before the value is reported;
    /// - the value is reported anyway once the oldest unreported change reaches ``maxPersistDelay``,
    ///   so a caller changing records in a steady stream can't defer the write indefinitely.
    ///
    ///
    /// An interval of `0` reports inline, which is what the tests use to stay deterministic.
    private func schedulePersist() {
        guard persistDebounceInterval > 0 else {
            persistCurrentValue()
            return
        }

        let item = DispatchWorkItem { [weak self] in
            self?.persistCurrentValue()
        }

        let delay: TimeInterval = state.withLock { state in
            state.pendingPersist?.cancel()
            state.pendingPersist = item

            let now = Date()
            guard let firstChange = state.firstPendingChange else {
                state.firstPendingChange = now
                return persistDebounceInterval
            }

            // Whatever is left of the max wait, so the deadline set by the first unreported change
            // survives every later change that pushes the debounce out.
            let remaining = maxPersistDelay - now.timeIntervalSince(firstChange)
            return max(0, min(persistDebounceInterval, remaining))
        }

        persistQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Reports whatever the current value is, clearing the pending state.
    ///
    /// Reads the value here rather than capturing it at schedule time: coalescing then comes for
    /// free, and a work item that fires late can't write a value the records have moved past.
    ///
    /// The write goes through `addRequiredResources` rather than the metadata handler because the
    /// value is exempt from the standard attribute length limit, and the metadata handler truncates.
    /// Called outside the lock, and it has to stay that way. Beyond not holding the lock across a
    /// database hop, the notification below is delivered synchronously, and its observer takes
    /// `SessionController`'s lock — which `startSession` holds while reading `encodedExperiments`.
    /// Persisting under the lock would invert that order and deadlock.
    ///
    /// The record exists so a later process can read back this process's value; it is deliberately
    /// kept out of the reported resources by `ResourcePayload`.
    private func persistCurrentValue() {
        let value: String? = state.withLock { state in
            state.pendingPersist = nil
            state.firstPendingChange = nil
            return state.encoded
        }

        guard let value = value else {
            return
        }

        storage?.addRequiredResources([SpanSemantics.keyExperiments: value])
        notificationCenter.post(name: .embraceExperimentsChanged, object: value)
    }

    /// Reports a pending value immediately, if there is one.
    ///
    /// Called when the app is about to background or terminate, where waiting out the debounce would
    /// mean the newest value is only seen on the next launch. This makes the value reach the CoreData
    /// context and the session span; getting the context itself to disk is `CoreDataWrapper`'s job,
    /// which runs its own save under a background task assertion.
    package func flushPendingPersist() {
        let pending: DispatchWorkItem? = state.withLock { $0.pendingPersist }

        guard let pending = pending else {
            return
        }

        pending.cancel()
        persistCurrentValue()
    }

    private func addLifecycleObservers() {
        #if canImport(UIKit) && !os(watchOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onAppWillSuspend),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onAppWillSuspend),
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        #elseif os(watchOS)
            if #available(watchOS 7.0, *) {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(onAppWillSuspend),
                    name: WKExtension.applicationDidEnterBackgroundNotification,
                    object: nil
                )
            }
        #endif
    }

    @objc private func onAppWillSuspend() {
        flushPendingPersist()
    }

    // MARK: - Config

    @objc private func onConfigUpdated(notification: Notification) {
        guard let config = notification.object as? EmbraceConfigurable else {
            return
        }

        // New limits only apply to records tracked from now on. Records already held are never
        // dropped retroactively.
        state.withLock { $0.limits = config.experimentsLimits }
    }
}
