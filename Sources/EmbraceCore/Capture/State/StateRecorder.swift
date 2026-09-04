//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// The type-erased face of a ``StateRecorder``, so the coordinator can drive recorders of
/// differing value types.
protocol StateRecording: AnyObject {

    /// Name of the state, e.g. `screen-automatic`.
    var stateName: String { get }

    /// Serialized current value, or `nil` if this state has not been activated yet. Lazily-activated
    /// states are absent from log metadata until their first change.
    var currentStateDescription: String? { get }

    /// Whether this state opens its span as soon as capture is enabled, rather than waiting for the
    /// first change. See ``StateRecorder/capturesOnCreation``.
    var capturesOnCreation: Bool { get }

    /// Opens this state's span for a newly started session part.
    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date)

    /// Closes this state's span. Must be called *synchronously* before the session part span ends,
    /// so the state span makes it into the part's payload and can be linked from it.
    func onSessionPartWillEnd(at time: Date)

    /// Closes this state's span for a part whose telemetry is being **thrown away**.
    ///
    /// Unlike ``onSessionPartWillEnd(at:)`` the accumulated counters are retained rather than
    /// flushed, because a span that is about to be discarded cannot carry them.
    func onSessionPartDiscarded(at time: Date)

    /// Marks the state as active, opening a span immediately if a session part is already running.
    func activate(at time: Date)
}

/// A transition the recorder has committed to under its lock, to be written to the span after the
/// lock is released.
private struct PendingTransition {
    let token: StateSpanToken
    let count: Int
    let flushed: UnrecordedTransitions
}

/// Records the history of one named, continuously-valued signal.
///
/// This is the reusable primitive behind every state: it owns the current value, the span currently
/// recording it, and the counts of changes that were not recorded. The screen state is its first
/// consumer; network and power states could be migrated onto it later without changing this type.
///
/// ## Guarantees
/// - **Value retention.** ``currentValue`` is updated before any decision to drop a change, so the
///   next span's `emb.state.initial_value` is right even when the change itself never became an event.
/// - **Lossless counting.** Dropped changes are counted and flushed onto the next recorded event, or
///   onto the span at close. If a write fails, the counts are put back rather than discarded.
/// - **Duplicate suppression.** Two equal consecutive values never produce two events.
///
/// ## Threading
/// All accounting happens under a single lock, so concurrent calls can neither lose counts nor open
/// two spans. Nothing that can **re-enter this type** is called while that lock is held — span
/// creation, `addEvent`, `setAttribute`, `end`, link writes and every log call happen after it is
/// released. Each method decides under the lock, performs its writes after releasing it, and
/// re-acquires to install a token or reconcile a failure.
///
/// The re-entrancy that forces this is not the exporter chain — customer exporters are dispatched
/// to a queue by `EmbraceSpanProcessor` and never run on the calling thread. It is the SDK's own
/// logging:
///
///     Embrace.logger.error(…) → BaseInternalLogger.sendOTelLog → internalLog
///       → LogController.createLog → EmbraceLogAttributesBuilder.addCurrentStates
///       → StateCaptureCoordinator.logAttributes → currentStateDescription → this lock
///
/// `EmbraceMutex` wraps a non-reentrant `os_unfair_lock`, so that path **traps** rather than
/// deadlocking. This type logs from several failure branches, which is why each one sits outside
/// the lock rather than inside the `withLock` closure that detected the failure.
///
/// The one exception is the `part.endTime` read in the install step, which touches the span while
/// this lock is held. It is a plain property read that takes only the span's own mutex and invokes
/// no callbacks — but it is the line to be careful around, because a span call or a log added
/// beside it would reintroduce exactly the hazard above.
///
/// A consequence worth naming: because the writes happen outside this lock, concurrent transitions
/// can write to the same span at once, so this relies on `EmbraceSpan` conformances being
/// thread-safe. `DefaultEmbraceSpan` is — it guards its events, links and attributes with its own
/// mutex — and any test double must be too.
///
/// Callers supply the observation time themselves so dispatch latency never skews event timestamps.
final class StateRecorder<Value: StateValue>: StateRecording {

    let stateName: String

    /// Per-session-part ceiling on recorded transitions. Overflow is counted, never recorded.
    let maxTransitions: Int

    /// Whether to open a span as soon as capture is enabled (eager) rather than waiting for the
    /// first change (lazy). Lazy states leave no default-value span behind in a changeless session.
    let capturesOnCreation: Bool

    private weak var otel: EmbraceOTelSignalsHandler?

    /// Where this recorder stands relative to the session part.
    ///
    /// Modelling the part and its token together makes "a token without a part" unrepresentable, and
    /// turns "a part started while one was already recording" into a case that can be reported
    /// rather than a silently-skipped guard.
    private enum PartRecording {
        case noPart
        case part(EmbraceSpan)
        case opening(EmbraceSpan)
        case recording(part: EmbraceSpan, token: StateSpanToken)
    }

    private struct Storage {
        var currentValue: Value
        var unrecorded: UnrecordedTransitions
        var isActive: Bool
        var recording: PartRecording

        /// Recorded transitions in the current part. Lives here rather than on the token because the
        /// cap decision must be made under the lock while the write happens outside it.
        var transitionsRecorded: Int
    }

    private let storage: EmbraceMutex<Storage>

    init(
        stateName: String,
        defaultValue: Value,
        otel: EmbraceOTelSignalsHandler?,
        maxTransitions: Int = 100,
        capturesOnCreation: Bool = true
    ) {
        self.stateName = stateName
        // A non-positive cap would silently convert every change into a dropped one.
        self.maxTransitions = max(1, maxTransitions)
        self.capturesOnCreation = capturesOnCreation
        self.otel = otel
        self.storage = EmbraceMutex(
            Storage(
                currentValue: defaultValue,
                unrecorded: .none,
                isActive: false,
                recording: .noPart,
                transitionsRecorded: 0
            )
        )
    }

    /// The live value, regardless of whether it was ever recorded.
    var currentValue: Value {
        storage.withLock { $0.currentValue }
    }

    var currentStateDescription: String? {
        storage.withLock { storage in
            storage.isActive ? storage.currentValue.stateDescription : nil
        }
    }

    // MARK: - Recording

    /// Records a change of this state's value.
    ///
    /// - Parameters:
    ///   - newValue: The new value. Equal to the current value means the change is counted as
    ///     dropped rather than recorded.
    ///   - time: When the change was *observed* — pass the timestamp captured at the originating
    ///     callback, not the time this method runs.
    ///   - attributes: Extra attributes for this transition. The reserved `emb.state.*` namespace is
    ///     stripped, so these can never overwrite the contract.
    ///   - coalescing: Number of changes the caller already collapsed into this one; counted as
    ///     dropped so the total stays accurate.
    func onStateChange(
        to newValue: Value,
        at time: Date,
        attributes: EmbraceAttributes = [:],
        coalescing coalescedTransitions: Int = 0
    ) {
        // Lazy states open their span on the first change. Done first, and outside the lock, so the
        // decision below sees the token this may install.
        openSpanIfNeeded(activating: true, at: time)

        let pending: PendingTransition? = storage.withLock { storage in
            // The value is retained before any drop decision below — this is what keeps the next
            // part's `initial_value` correct even when this change is never recorded.
            let oldValue = storage.currentValue
            storage.currentValue = newValue
            storage.unrecorded.droppedByInstrumentation += max(0, coalescedTransitions)

            guard case .recording(_, let token) = storage.recording else {
                storage.unrecorded.notInSession += 1
                return nil
            }

            guard newValue != oldValue else {
                // Duplicate suppression belongs to the infrastructure, not to the feature; the
                // caller's attributes for this change are discarded along with it.
                storage.unrecorded.droppedByInstrumentation += 1
                return nil
            }

            guard storage.transitionsRecorded < maxTransitions else {
                storage.unrecorded.droppedByInstrumentation += 1
                return nil
            }

            storage.transitionsRecorded += 1
            let flushed = storage.unrecorded
            storage.unrecorded = .none

            return PendingTransition(token: token, count: storage.transitionsRecorded, flushed: flushed)
        }

        guard let pending else {
            return
        }

        let outcome = pending.token.recordTransition(
            value: newValue.stateDescription,
            at: time,
            count: pending.count,
            attributes: attributes,
            flushing: pending.flushed
        )

        guard outcome != .recorded else {
            return
        }

        // The write failed. Put the flushed counts back — adding rather than assigning, since other
        // threads may have accumulated more while the lock was released — and give up this
        // transition's slot in the per-part budget.
        storage.withLock { storage in
            storage.transitionsRecorded = max(0, storage.transitionsRecorded - 1)

            switch outcome {
            case .spanEnded:
                if case .recording(let part, let token) = storage.recording, token === pending.token {
                    storage.recording = .part(part)
                }
                // The part was torn down underneath us: recycle as a change outside a session part.
                storage.unrecorded = storage.unrecorded + pending.flushed + UnrecordedTransitions(notInSession: 1)
            case .eventDropped, .recorded:
                storage.unrecorded =
                    storage.unrecorded + pending.flushed + UnrecordedTransitions(droppedByInstrumentation: 1)
            }
        }

        if outcome == .eventDropped {
            Embrace.logger.warning(
                "State '\(stateName)': a transition event was dropped by the span; counted as dropped instead.")
        }

        if outcome == .spanEnded {
            Embrace.logger.error(
                "State '\(stateName)': the state span was ended by something other than this recorder; "
                    + "a new span will be opened on the next change.")
        }
    }

    // MARK: - Session part boundaries

    func activate(at time: Date) {
        openSpanIfNeeded(activating: true, at: time)
    }

    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date) {
        // Binding to an already-closed part would open a span that outlives it and gets linked from
        // the wrong part. This makes a registration racing a part boundary harmless.
        guard sessionSpan.endTime == nil else {
            Embrace.logger.warning(
                "State '\(stateName)': ignoring a part start for an already-ended session span.")
            return
        }

        let stale: (token: StateSpanToken, part: EmbraceSpan, count: Int)? = storage.withLock { storage in
            var stale: (StateSpanToken, EmbraceSpan, Int)?
            if case .recording(let part, let token) = storage.recording {
                // Captured before the reset below, which would otherwise take the count with it.
                stale = (token, part, storage.transitionsRecorded)
            }
            storage.recording = .part(sessionSpan)
            storage.transitionsRecorded = 0
            return stale
        }

        // A live token at a part start can only mean the previous part was never closed. Report it
        // and clean up, rather than silently leaving the old span open and mis-attributing.
        if let stale {
            Embrace.logger.error(
                "State '\(stateName)': a span was still open at part start; the previous part was not closed.")
            close(token: stale.token, linkingFrom: stale.part, at: time, flushing: .none, count: stale.count)
        }

        openSpanIfNeeded(activating: false, at: time)
    }

    func onSessionPartWillEnd(at time: Date) {
        let pending: (token: StateSpanToken, part: EmbraceSpan, flushed: UnrecordedTransitions, count: Int)? =
            storage.withLock { storage in
                defer { storage.recording = .noPart }

                guard case .recording(let part, let token) = storage.recording else {
                    return nil
                }
                let flushed = storage.unrecorded
                storage.unrecorded = .none
                // Read in the same critical section as `flushed`, so the count written to the span
                // can never disagree with the counters written alongside it.
                return (token, part, flushed, storage.transitionsRecorded)
            }

        guard let pending else {
            return
        }
        close(
            token: pending.token,
            linkingFrom: pending.part,
            at: time,
            flushing: pending.flushed,
            count: pending.count
        )
    }

    func onSessionPartDiscarded(at time: Date) {
        let pending: (token: StateSpanToken, count: Int)? = storage.withLock { storage in
            defer { storage.recording = .noPart }

            guard case .recording(_, let token) = storage.recording else {
                return nil
            }
            // The counters are deliberately NOT flushed: this span is being thrown away with its
            // part, so they have to survive into the next part instead.
            return (token, storage.transitionsRecorded)
        }

        // The count is still written: the span outlives the deleted part in storage, so if it ever
        // does surface it should describe itself accurately.
        pending?.token.end(at: time, flushing: .none, count: pending?.count ?? 0)
    }

    // MARK: - Private

    /// Opens the state span if this recorder is active and a part is running but has no span yet.
    ///
    /// Span creation happens outside the lock; the resulting token is installed under it, and a span
    /// that lost its part in between is closed rather than leaked.
    private func openSpanIfNeeded(activating: Bool, at time: Date) {
        // No live session part means no span. Changes in that window accumulate as
        // `not_in_session` and land on the next part's first recorded transition.
        let initialValue: String? = storage.withLock { storage in
            if activating {
                storage.isActive = true
            }
            // Claiming the part is what makes this exclusive: a caller arriving at `.opening` or
            // `.recording` creates nothing, because someone else already owns the open.
            guard storage.isActive, case .part(let part) = storage.recording else {
                return nil
            }
            storage.recording = .opening(part)
            return storage.currentValue.stateDescription
        }

        guard let initialValue else {
            return
        }

        // The slot is now claimed, so every exit below must either install a token or hand it back.
        // An abandoned `.opening` would block every later open attempt and leave this recorder
        // inert for the rest of the part — a worse failure than the duplicate span it prevents.
        var installed = false
        defer {
            if !installed {
                storage.withLock { storage in
                    if case .opening(let part) = storage.recording {
                        storage.recording = .part(part)
                    }
                }
            }
        }

        guard let otel else {
            Embrace.logger.error(
                "State '\(stateName)': no OTel handler available; state capture is inert for this part.")
            return
        }

        let span: EmbraceSpan
        do {
            span = try otel.createInternalSpan(
                name: SpanSemantics.State.spanName(for: stateName),
                type: .state,
                startTime: time,
                attributes: [
                    SpanSemantics.State.keyInitialValue: initialValue
                ]
            )
        } catch {
            Embrace.logger.error(
                "State '\(stateName)': failed to create the state span: \(error.localizedDescription)")
            return
        }

        let orphaned: Bool = storage.withLock { storage in
            // Anything other than the claim we made means the part moved on underneath us — it
            // ended, was discarded, or a new part started. Either way this span is not wanted.
            guard case .opening(let part) = storage.recording, part.endTime == nil else {
                return true
            }
            storage.recording = .recording(part: part, token: StateSpanToken(span: span))
            storage.transitionsRecorded = 0
            installed = true
            return false
        }

        if orphaned {
            // The part ended while the span was being created. Close it so it isn't left open.
            span.end(endTime: time)
        }
    }

    /// Ends a state span and links it from its part span. Must be called outside the lock.
    private func close(
        token: StateSpanToken,
        linkingFrom part: EmbraceSpan,
        at time: Date,
        flushing flushed: UnrecordedTransitions,
        count: Int
    ) {
        if !token.end(at: time, flushing: flushed, count: count) && !flushed.isEmpty {
            // The span had already ended, so the residual counts were not written. Retain them for
            // the next part instead of losing them.
            storage.withLock { $0.unrecorded = $0.unrecorded + flushed }
            Embrace.logger.warning(
                "State '\(stateName)': span had already ended at close; residual counts carried to the next part.")
        }

        // The session part span links to the state span so the backend can find a part's states.
        // This is a structural link the SDK owns, so it uses the internal path: a busy session's
        // customer links and events must not be able to squeeze it out.
        let link = part.addInternalLink(
            spanId: token.span.context.spanId,
            traceId: token.span.context.traceId,
            attributes: [SpanSemantics.keyLinkType: SpanSemantics.State.linkType]
        )

        if link == nil {
            Embrace.logger.error(
                "State '\(stateName)': failed to link the state span from its session part span; "
                    + "the span will not be reachable from the part.")
        }
    }
}
