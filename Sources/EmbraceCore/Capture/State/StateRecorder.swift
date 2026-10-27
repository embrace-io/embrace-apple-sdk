//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// The type-erased face of a ``StateRecorder``, so the state controller can drive recorders of
/// differing value types.
protocol StateRecording: AnyObject {

    /// This state's `emb.state.<name>` log stamp, plus its value type when it is a system value.
    /// Empty until the state has a value.
    var logAttributes: EmbraceAttributes { get }

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
}

/// Records the history of one named, continuously-valued signal: the current value, the span
/// recording it, and the counts of changes that were not recorded.
///
/// ## Starting value
/// A state created with an `initialValue` opens a span on every part. One created without waits
/// for its first ``onStateChange(to:at:attributes:)``: that value is the state's starting value
/// rather than a transition, so it opens the span as `initial_value` and is never counted. Until
/// then the state has no span and no log stamp.
///
/// ## Guarantees
/// - **Value retention.** ``currentValue`` updates before any decision to drop a change, so the next
///   span's `initial_value` is right even when the change never became an event.
/// - **Lossless counting.** Dropped changes are counted and flushed onto the next recorded event, or
///   onto the span at close. A failed write puts its counts back.
/// - **Duplicate suppression.** Two equal consecutive values never produce two events.
/// - **One span per part.** A span opens at part start or on the first value, never again within
///   the same part.
///
/// Only this type ends a state span. A write that finds its span ended therefore means the part
/// ended between the decision and the write, and the change is counted as outside a part.
///
/// ## Threading
/// Every method decides under the lock, performs its span writes after releasing it, then
/// re-acquires to install a span or reconcile a failure. Nothing that can re-enter this type runs
/// while the lock is held.
///
/// What forces that is the SDK's own logging, not the exporter chain: a log call reaches
/// `StateController.logAttributes` and back into this lock, which is non-reentrant and so
/// **traps** rather than deadlocking. This type logs from several failure branches, which is why
/// each sits outside the `withLock` that detected it.
///
/// The one exception is the `part.endTime` read in the install step — a plain property read taking
/// only the span's own mutex. It is the line to be careful around: a span call or a log added beside
/// it reintroduces the hazard.
///
/// Because writes happen outside the lock, concurrent transitions can write the same span, so
/// `EmbraceSpan` conformances must be thread-safe — test doubles included.
///
/// Callers supply the observation time so dispatch latency never skews event timestamps.
final class StateRecorder<Value: StateValue>: StateRecording {

    let stateName: String

    /// Per-session-part ceiling on recorded transitions. Overflow is counted, never recorded.
    let maxTransitions: Int

    private weak var otel: EmbraceOTelSignalsHandler?

    private let sanitizer: OTelSignalsSanitizer

    /// Counts of state changes that were **not** recorded as `transition` events.
    ///
    /// They ride along with the next recorded event, or land on the span at close, so the total
    /// number of changes is always reconstructable even when individual events are missing.
    private struct UnrecordedTransitions {

        /// Changes that occurred while no session part was recording.
        var notInSession: Int = 0

        /// Changes the instrumentation dropped on purpose: duplicates of the current value and
        /// overflow past the per-part cap.
        var droppedByInstrumentation: Int = 0

        /// A zero counter is omitted rather than written as `"0"` — its absence is what the wire
        /// contract specifies.
        var attributes: EmbraceAttributes {
            var attributes: EmbraceAttributes = [:]
            if notInSession > 0 {
                attributes[SpanSemantics.State.keyNotInSession] = String(notInSession)
            }
            if droppedByInstrumentation > 0 {
                attributes[SpanSemantics.State.keyDroppedByInstrumentation] = String(droppedByInstrumentation)
            }
            return attributes
        }

        static func + (lhs: UnrecordedTransitions, rhs: UnrecordedTransitions) -> UnrecordedTransitions {
            UnrecordedTransitions(
                notInSession: lhs.notInSession + rhs.notInSession,
                droppedByInstrumentation: lhs.droppedByInstrumentation + rhs.droppedByInstrumentation
            )
        }
    }

    /// A transition decided under the lock, to be written to the span after it is released.
    private struct PendingTransition {
        let span: EmbraceSpan
        let count: Int
        let flushed: UnrecordedTransitions
    }

    /// What ``onStateChange(to:at:attributes:)`` decided to do under the lock.
    private enum ChangeDecision {
        case none
        case start
        case record(PendingTransition)
    }

    /// Where this recorder stands relative to the session part.
    ///
    /// Modelling the part and its span together makes "a span without a part" unrepresentable, and
    /// turns "a part started while one was already recording" into a case that can be reported
    /// rather than a silently-skipped guard.
    private enum PartRecording {
        case noPart
        case part(EmbraceSpan)
        case opening(EmbraceSpan)
        case recording(part: EmbraceSpan, span: EmbraceSpan)
    }

    private struct Storage {
        var currentValue: Value?
        var unrecorded = UnrecordedTransitions()
        var recording: PartRecording = .noPart

        /// Recorded transitions in the current part. Kept here because the cap decision must be made
        /// under the lock while the write happens outside it.
        var transitionsRecorded = 0
    }

    private let storage: EmbraceMutex<Storage>

    init(
        stateName: String,
        initialValue: Value?,
        otel: EmbraceOTelSignalsHandler?,
        maxTransitions: Int = 100,
        sanitizer: OTelSignalsSanitizer = DefaultOtelSignalsSanitizer()
    ) {
        self.sanitizer = sanitizer
        self.stateName = stateName
        // A non-positive cap would silently convert every change into a dropped one.
        self.maxTransitions = max(1, maxTransitions)
        self.otel = otel
        self.storage = EmbraceMutex(Storage(currentValue: initialValue))
    }

    /// The live value, regardless of whether it was ever recorded. `nil` until the state has one.
    var currentValue: Value? {
        storage.withLock { $0.currentValue }
    }

    var logAttributes: EmbraceAttributes {
        // Copied once, so the value and its type always come from the same read.
        guard let value = currentValue else {
            return [:]
        }
        return value.attributes(
            valueKey: SpanSemantics.State.logAttributeKey(for: stateName),
            typeKey: SpanSemantics.State.logValueTypeAttributeKey(for: stateName)
        )
    }

    // MARK: - Recording

    /// Records a change of this state's value.
    ///
    /// - Parameters:
    ///   - newValue: The new value. Equal to the current value means the change is counted as
    ///     dropped rather than recorded. The first value of a state created without one is its
    ///     starting value instead, and opens the span.
    ///   - time: When the change was *observed* — pass the timestamp captured at the originating
    ///     callback, not the time this method runs.
    ///   - attributes: Extra attributes for this transition. The reserved `emb.state.*` namespace is
    ///     stripped, so these can never overwrite the contract. Unused for a starting value, which
    ///     is not an event.
    func onStateChange(to newValue: Value, at time: Date, attributes: EmbraceAttributes = [:]) {
        let decision: ChangeDecision = storage.withLock { storage in
            // The value is retained before any drop decision below — this is what keeps the next
            // part's `initial_value` correct even when this change is never recorded.
            let oldValue = storage.currentValue
            storage.currentValue = newValue

            guard let oldValue else {
                return .start
            }

            guard case .recording(_, let span) = storage.recording else {
                storage.unrecorded.notInSession += 1
                return .none
            }

            guard newValue != oldValue else {
                // Duplicate suppression belongs to the infrastructure, not to the feature; the
                // caller's attributes for this change are discarded along with it.
                storage.unrecorded.droppedByInstrumentation += 1
                return .none
            }

            guard storage.transitionsRecorded < maxTransitions else {
                storage.unrecorded.droppedByInstrumentation += 1
                return .none
            }

            storage.transitionsRecorded += 1
            let flushed = storage.unrecorded
            storage.unrecorded = UnrecordedTransitions()

            return .record(PendingTransition(span: span, count: storage.transitionsRecorded, flushed: flushed))
        }

        switch decision {
        case .none:
            return
        case .start:
            openSpanIfNeeded(at: time)
        case .record(let pending):
            record(pending, value: newValue, at: time, attributes: attributes)
        }
    }

    private func record(_ pending: PendingTransition, value: Value, at time: Date, attributes: EmbraceAttributes) {
        let recorded = recordTransition(
            on: pending.span,
            value: value,
            at: time,
            count: pending.count,
            attributes: attributes,
            flushing: pending.flushed
        )

        guard !recorded else {
            return
        }

        // The part ended between the decision and the write, so the change happened outside it. The
        // counts it was carrying go back too — added rather than assigned, since other threads may
        // have accumulated more while the lock was released.
        storage.withLock { storage in
            storage.unrecorded = storage.unrecorded + pending.flushed + UnrecordedTransitions(notInSession: 1)
        }
    }

    // MARK: - Session part boundaries

    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date) {
        // Binding to an already-closed part would open a span that outlives it and gets linked from
        // the wrong part. This makes a registration racing a part boundary harmless.
        guard sessionSpan.endTime == nil else {
            Embrace.logger.warning(
                "State '\(stateName)': ignoring a part start for an already-ended session span.")
            return
        }

        let stale: (span: EmbraceSpan, part: EmbraceSpan, count: Int)? = storage.withLock { storage in
            var stale: (EmbraceSpan, EmbraceSpan, Int)?
            if case .recording(let part, let span) = storage.recording {
                // Captured before the reset below, which would otherwise take the count with it.
                stale = (span, part, storage.transitionsRecorded)
            }
            storage.recording = .part(sessionSpan)
            storage.transitionsRecorded = 0
            return stale
        }

        // A live span at a part start can only mean the previous part was never closed. Report it
        // and clean up, rather than silently leaving the old span open and mis-attributing.
        if let stale {
            Embrace.logger.error(
                "State '\(stateName)': a span was still open at part start; the previous part was not closed.")
            close(stale.span, linkingFrom: stale.part, at: time, flushing: UnrecordedTransitions(), count: stale.count)
        }

        openSpanIfNeeded(at: time)
    }

    func onSessionPartWillEnd(at time: Date) {
        let pending: (span: EmbraceSpan, part: EmbraceSpan, flushed: UnrecordedTransitions, count: Int)? =
            storage.withLock { storage in
                defer { storage.recording = .noPart }

                guard case .recording(let part, let span) = storage.recording else {
                    return nil
                }
                let flushed = storage.unrecorded
                storage.unrecorded = UnrecordedTransitions()
                // Read in the same critical section as `flushed`, so the count written to the span
                // can never disagree with the counters written alongside it.
                return (span, part, flushed, storage.transitionsRecorded)
            }

        guard let pending else {
            return
        }
        close(pending.span, linkingFrom: pending.part, at: time, flushing: pending.flushed, count: pending.count)
    }

    func onSessionPartDiscarded(at time: Date) {
        let pending: (span: EmbraceSpan, count: Int)? = storage.withLock { storage in
            defer { storage.recording = .noPart }

            guard case .recording(_, let span) = storage.recording else {
                return nil
            }
            // The counters are deliberately NOT flushed: this span is being thrown away with its
            // part, so they have to survive into the next part instead.
            return (span, storage.transitionsRecorded)
        }

        // The count is still written: the span outlives the deleted part in storage, so if it ever
        // does surface it should describe itself accurately.
        if let pending {
            end(pending.span, at: time, flushing: UnrecordedTransitions(), count: pending.count)
        }
    }

    // MARK: - Private

    /// Opens the state span if the state has a value and a part is running but has no span yet.
    ///
    /// Span creation happens outside the lock; the resulting span is installed under it, and a span
    /// that lost its part in between is closed rather than leaked.
    private func openSpanIfNeeded(at time: Date) {
        // No live session part means no span. Changes in that window accumulate as
        // `not_in_session` and land on the next part's first recorded transition.
        let initialValue: Value? = storage.withLock { storage in
            // Claiming the part is what makes this exclusive: a caller arriving at `.opening` or
            // `.recording` creates nothing, because someone else already owns the open.
            guard let value = storage.currentValue, case .part(let part) = storage.recording else {
                return nil
            }
            storage.recording = .opening(part)
            return value
        }

        guard let initialValue else {
            return
        }

        // A failed open leaves the claim in place: nothing else opens a span within this part, so
        // the part's changes count as `not_in_session` and the next part boundary resets it.
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
                // Scoped to `initial_value`: written once at span start, never rewritten however the
                // value is typed later in the part.
                attributes: initialValue.attributes(
                    valueKey: SpanSemantics.State.keyInitialValue,
                    typeKey: SpanSemantics.State.keyValueType
                )
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
            storage.recording = .recording(part: part, span: span)
            storage.transitionsRecorded = 0
            return false
        }

        if orphaned {
            // The part ended while the span was being created. Close it so it isn't left open.
            span.end(endTime: time)
        }
    }

    /// Writes a `transition` event and the running transition count. Must be called outside the lock.
    ///
    /// - Returns: `false` if the span had already ended, in which case nothing was written.
    private func recordTransition(
        on span: EmbraceSpan,
        value: Value,
        at time: Date,
        count: Int,
        attributes: EmbraceAttributes,
        flushing flushed: UnrecordedTransitions
    ) -> Bool {
        guard span.endTime == nil else {
            return false
        }

        var eventAttributes = bounded(attributes)
        eventAttributes.merge(flushed.attributes) { _, builtIn in builtIn }
        eventAttributes.merge(
            value.attributes(
                valueKey: SpanSemantics.State.keyNewValue,
                typeKey: SpanSemantics.State.keyValueType
            )
        ) { _, builtIn in builtIn }

        // Internal spans bypass the customer-facing per-span event limit (see
        // `StateRecorderLimitsTests`), so this only fails if the span ended since the check above.
        guard
            span.addEvent(
                name: SpanSemantics.State.transitionEventName,
                type: nil,
                timestamp: time,
                attributes: eventAttributes
            ) != nil
        else {
            return false
        }

        span.setAttribute(key: SpanSemantics.State.keyTransitionCount, value: String(count))
        return true
    }

    /// Filters and bounds attributes that came from outside the SDK.
    ///
    /// State spans are internal, and `isInternal` skips sanitization — an exemption written when
    /// every attribute here was the SDK's own. A public API taking caller attributes changes that,
    /// so the sanitizer is applied by hand. It bounds keys and values but preserves the
    /// non-`String` cases of `EmbraceAttributeValue`.
    ///
    /// The reserved filter runs first rather than relying on the later merge to overwrite: the
    /// counter keys are omitted when zero, so a forged `emb.state.not_in_session` would survive on
    /// any event without counts.
    private func bounded(_ callerAttributes: EmbraceAttributes) -> EmbraceAttributes {
        let allowed = callerAttributes.filter { !SpanSemantics.State.isReserved($0.key) }
        return sanitizer.sanitizeSpanEventAttributes(allowed)
    }

    /// Writes the transition count and any residual counts onto the span, then closes it. Must be
    /// called outside the lock.
    private func end(_ span: EmbraceSpan, at time: Date, flushing flushed: UnrecordedTransitions, count: Int) {
        span.setAttribute(key: SpanSemantics.State.keyTransitionCount, value: String(count))
        for (key, value) in flushed.attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(endTime: time)
    }

    /// Ends a state span and links it from its part span. Must be called outside the lock.
    private func close(
        _ span: EmbraceSpan,
        linkingFrom part: EmbraceSpan,
        at time: Date,
        flushing flushed: UnrecordedTransitions,
        count: Int
    ) {
        end(span, at: time, flushing: flushed, count: count)

        // The session part span links to the state span so the backend can find a part's states. It
        // counts against the span's link limit, but nothing else links from a part span: each state
        // takes one slot.
        let link = part.addLink(
            spanId: span.context.spanId,
            traceId: span.context.traceId,
            attributes: [SpanSemantics.keyLinkType: SpanSemantics.State.linkType]
        )

        if link == nil {
            Embrace.logger.error(
                "State '\(stateName)': failed to link the state span from its session part span; "
                    + "the span will not be reachable from the part.")
        }
    }
}
