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

    /// Name of the state, e.g. `screen-automatic`. Forms the span name and the log attribute key.
    var stateName: String { get }

    /// The `emb.state.<name>` stamp for the current value, or `nil` if this state has not been
    /// activated yet. Lazily-activated states are absent from log metadata until their first change.
    var logAttribute: (key: String, value: String)? { get }

    /// Whether this state opens its span as soon as capture is enabled, rather than waiting for the
    /// first change.
    var capturesOnCreation: Bool { get }

    /// Opens this state's span for a newly started session part.
    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date)

    /// Closes this state's span. Must be called *synchronously* before the session part span ends,
    /// so the state span makes it into the part's payload and can be linked from it.
    func onSessionPartWillEnd(at time: Date)

    /// Marks the state as active, opening a span immediately if a session part is already running.
    /// Eager states are activated as soon as capture is enabled.
    func activate(at time: Date)
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
///   onto the span at close.
/// - **Duplicate suppression.** Two equal consecutive values never produce two events.
///
/// ## Threading
/// Every mutation runs under a single lock, so concurrent ``onStateChange(to:at:attributes:coalescing:)``
/// calls can neither lose counts nor open two spans. Callers supply the observation time themselves
/// so dispatch latency never skews event timestamps.
final class StateRecorder<Value: StateValue>: StateRecording {

    let stateName: String

    /// Per-session-part ceiling on recorded transitions. Overflow is counted, never recorded.
    let maxTransitions: Int

    /// Whether to open a span as soon as capture is enabled (eager) rather than waiting for the
    /// first change (lazy). Lazy states leave no default-value span behind in a changeless session.
    let capturesOnCreation: Bool

    private weak var otel: EmbraceOTelSignalsHandler?

    private struct Storage {
        var currentValue: Value
        var token: StateSpanToken?
        var unrecorded: UnrecordedTransitions
        var isActive: Bool
        var sessionSpan: EmbraceSpan?
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
        self.maxTransitions = maxTransitions
        self.capturesOnCreation = capturesOnCreation
        self.otel = otel
        self.storage = EmbraceMutex(
            Storage(
                currentValue: defaultValue,
                token: nil,
                unrecorded: .none,
                isActive: false,
                sessionSpan: nil
            )
        )
    }

    /// The live value, regardless of whether it was ever recorded.
    var currentValue: Value {
        storage.withLock { $0.currentValue }
    }

    var logAttribute: (key: String, value: String)? {
        storage.withLock { storage in
            guard storage.isActive else {
                return nil
            }
            return (
                SpanSemantics.State.logAttributeKey(for: stateName),
                storage.currentValue.stateDescription
            )
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
    ///   - attributes: Extra attributes for this transition. The built-in `emb.state.*` keys always
    ///     take precedence, so these can never overwrite the contract.
    ///   - coalescing: Number of changes the caller already collapsed into this one; counted as
    ///     dropped so the total stays accurate.
    func onStateChange(
        to newValue: Value,
        at time: Date,
        attributes: EmbraceAttributes = [:],
        coalescing coalescedTransitions: Int = 0
    ) {
        storage.withLock { storage in
            // Lazy states open their span on the first change rather than at enable time.
            if !storage.isActive {
                activate(&storage, at: time)
            }

            // The value is retained before any drop decision below — this is what keeps the next
            // part's `initial_value` correct even when this change is never recorded.
            let oldValue = storage.currentValue
            storage.currentValue = newValue
            storage.unrecorded.droppedByInstrumentation += coalescedTransitions

            guard let token = storage.token else {
                storage.unrecorded.notInSession += 1
                return
            }

            guard newValue != oldValue else {
                // Duplicate suppression belongs to the infrastructure, not to the feature; the
                // caller's attributes for this change are discarded along with it.
                storage.unrecorded.droppedByInstrumentation += 1
                return
            }

            guard token.transitionCount < maxTransitions else {
                storage.unrecorded.droppedByInstrumentation += 1
                return
            }

            let flushed = storage.unrecorded
            storage.unrecorded = .none

            let recorded = token.recordTransition(
                value: newValue.stateDescription,
                at: time,
                attributes: attributes,
                flushing: flushed
            )

            if !recorded {
                // The span was closed underneath us. Put the flushed counts back and count this
                // change as having happened outside a session part rather than losing it.
                storage.unrecorded = flushed + UnrecordedTransitions(notInSession: 1)
            }
        }
    }

    // MARK: - Session part boundaries

    func activate(at time: Date) {
        storage.withLock { activate(&$0, at: time) }
    }

    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date) {
        storage.withLock { storage in
            storage.sessionSpan = sessionSpan
            guard storage.isActive else {
                return
            }
            openSpan(&storage, at: time)
        }
    }

    func onSessionPartWillEnd(at time: Date) {
        storage.withLock { storage in
            closeSpan(&storage, at: time)
            storage.sessionSpan = nil
        }
    }

    // MARK: - Private

    private func activate(_ storage: inout Storage, at time: Date) {
        guard !storage.isActive else {
            return
        }
        storage.isActive = true
        openSpan(&storage, at: time)
    }

    private func openSpan(_ storage: inout Storage, at time: Date) {
        // No live session part means no span. Changes in that window accumulate as
        // `not_in_session` and land on the next part's first recorded transition.
        guard storage.sessionSpan != nil, storage.token == nil else {
            return
        }

        let span = try? otel?.createInternalSpan(
            name: SpanSemantics.State.spanName(for: stateName),
            type: .state,
            startTime: time,
            attributes: [
                SpanSemantics.State.keyInitialValue: storage.currentValue.stateDescription
            ]
        )

        storage.token = span.map { StateSpanToken(span: $0) }
    }

    private func closeSpan(_ storage: inout Storage, at time: Date) {
        guard let token = storage.token else {
            return
        }
        storage.token = nil

        let flushed = storage.unrecorded
        storage.unrecorded = .none
        token.end(at: time, flushing: flushed)

        // The session part span links to the state span so the backend can find a part's states.
        storage.sessionSpan?.addLink(
            spanId: token.span.context.spanId,
            traceId: token.span.context.traceId,
            attributes: [SpanSemantics.keyLinkType: SpanSemantics.State.linkType]
        )
    }
}
