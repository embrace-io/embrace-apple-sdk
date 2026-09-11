//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Fans session-part boundaries out to the registered state recorders, and exposes the current
/// value of every active state for log stamping.
///
/// Driven by direct calls from ``SessionController`` rather than by the part-lifecycle
/// notification, which is posted with `DispatchQueue.main.async` and so carries no ordering
/// guarantee against the part span being ended right after it.
///
/// Recorders are snapshotted under the lock and driven **outside** it. A recorder can log while
/// closing its span, and the SDK's logging path reaches ``logAttributes``, which takes this same
/// non-reentrant lock on the same thread — driving them under it would trap.
final class StateCaptureCoordinator {

    private let recorders: EmbraceMutex<[StateRecording]> = EmbraceMutex([])

    /// Registers a recorder and, for eager states, activates it right away.
    ///
    /// There is no `unregister`: once registered, a recorder opens a span on every subsequent part
    /// for the lifetime of the SDK. Any config gate must therefore be evaluated *before* this call.
    ///
    /// - Parameters:
    ///   - recorder: Held strongly — the coordinator owns the state history independently of
    ///     whichever capture service created it.
    ///   - sessionSpan: The live part span, if one is running. An already-ended span is rejected by
    ///     the recorder, so a boundary racing this call cannot bind it to a dead part.
    ///   - time: Registration time, used as the span start when the state is eager.
    func register(_ recorder: StateRecording, sessionSpan: EmbraceSpan?, at time: Date = Date()) {
        recorders.withLock { $0.append(recorder) }

        if let sessionSpan {
            recorder.onSessionPartStart(sessionSpan: sessionSpan, at: time)
        }
        if recorder.capturesOnCreation {
            recorder.activate(at: time)
        }
    }

    /// Opens a state span for every registered state on the newly started part.
    ///
    /// Must run after the part is published and before any transition can be reported against it, or
    /// a change arriving in the gap is counted as having happened outside a part.
    func onSessionPartStart(sessionSpan: EmbraceSpan, at time: Date = Date()) {
        for recorder in recorders.safeValue {
            recorder.onSessionPartStart(sessionSpan: sessionSpan, at: time)
        }
    }

    /// Closes every state span. Must run before the session part span is ended.
    func onSessionPartWillEnd(at time: Date = Date()) {
        for recorder in recorders.safeValue {
            recorder.onSessionPartWillEnd(at: time)
        }
    }

    /// Closes every state span for a part whose telemetry is being discarded, retaining the
    /// accumulated counters for the next part.
    func onSessionPartDiscarded(at time: Date = Date()) {
        for recorder in recorders.safeValue {
            recorder.onSessionPartDiscarded(at: time)
        }
    }

    /// `emb.state.<name>` stamps for every currently active state, for log metadata.
    ///
    /// Gathered per recorder rather than atomically, so a log can see one state's new value beside
    /// another's old one. That is acceptable here, and must not be "fixed" by holding a lock across
    /// the recorders — see the note on this type.
    var logAttributes: EmbraceAttributes {
        var attributes: EmbraceAttributes = [:]
        for recorder in recorders.safeValue {
            guard let value = recorder.currentStateDescription else {
                continue
            }
            attributes[SpanSemantics.State.logAttributeKey(for: recorder.stateName)] = value
        }
        return attributes
    }
}
