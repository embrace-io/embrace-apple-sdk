//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Fans session-part boundaries out to the registered state recorders, and exposes the current
/// value of every state that has one for log stamping.
///
/// Driven by direct calls from ``SessionController`` rather than by the part-lifecycle
/// notification, which is posted with `DispatchQueue.main.async` and so carries no ordering
/// guarantee against the part span being ended right after it.
///
/// Recorders are snapshotted under the lock and driven **outside** it. A recorder can log while
/// closing its span, and the SDK's logging path reaches ``logAttributes``, which takes this same
/// non-reentrant lock on the same thread — driving them under it would trap.
final class StateController {

    private struct State {
        var recorders: [StateRecording] = []

        /// The running part's span, so a recorder registered mid-part can open its span on it.
        var currentPart: EmbraceSpan?
    }

    private let state = EmbraceMutex(State())

    /// Registers a recorder, opening its span right away if a part is running and the state has a value.
    ///
    /// There is no `unregister`: once registered, a recorder opens a span on every subsequent part
    /// for the lifetime of the SDK. Any config gate must therefore be evaluated *before* this call.
    ///
    /// The recorder is added and the running part read in one locked section, so a part boundary
    /// either sees the new recorder or has already been read here — never neither.
    ///
    /// - Parameters:
    ///   - recorder: Held strongly — the state controller owns the state history independently of
    ///     whichever capture service created it.
    ///   - time: Registration time, used as the span start.
    func register(_ recorder: StateRecording, at time: Date = Date()) {
        let currentPart = state.withLock {
            $0.recorders.append(recorder)
            return $0.currentPart
        }

        // An already-ended span is rejected by the recorder, so a part ending right after the read
        // above cannot bind the recorder to a dead part.
        if let currentPart {
            recorder.onSessionPartStart(sessionSpan: currentPart, at: time)
        }
    }

    /// Opens a state span for every registered state on the newly started part.
    ///
    /// Must run after the part is published and before any transition can be reported against it, or
    /// a change arriving in the gap is counted as having happened outside a part.
    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date = Date()) {
        let recorders = state.withLock {
            $0.currentPart = sessionSpan
            return $0.recorders
        }
        for recorder in recorders {
            recorder.onSessionPartStart(sessionSpan: sessionSpan, at: time)
        }
    }

    /// Closes every state span. Must run before the session part span is ended.
    func onSessionPartWillEnd(at time: Date = Date()) {
        for recorder in endCurrentPart() {
            recorder.onSessionPartWillEnd(at: time)
        }
    }

    /// Closes every state span for a part whose telemetry is being discarded, retaining the
    /// accumulated counters for the next part.
    func onSessionPartDiscarded(at time: Date = Date()) {
        for recorder in endCurrentPart() {
            recorder.onSessionPartDiscarded(at: time)
        }
    }

    /// `emb.state.<name>` stamps for every state that has a value, plus `emb.state.<name>.value_type`
    /// for system values, for log metadata.
    ///
    /// Gathered per recorder rather than atomically, so a log can see one state's new value beside
    /// another's old one. That is acceptable here, and must not be "fixed" by holding a lock across
    /// the recorders — see the note on this type.
    var logAttributes: EmbraceAttributes {
        var attributes: EmbraceAttributes = [:]
        for recorder in state.withLock({ $0.recorders }) {
            attributes.merge(recorder.logAttributes) { _, new in new }
        }
        return attributes
    }

    private func endCurrentPart() -> [StateRecording] {
        state.withLock {
            $0.currentPart = nil
            return $0.recorders
        }
    }
}
