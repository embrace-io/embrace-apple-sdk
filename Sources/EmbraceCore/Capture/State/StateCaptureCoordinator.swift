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
/// This exists because state spans have to be opened and closed at a precise point in the part
/// lifecycle: `embraceSessionPartWillEnd` is posted with `DispatchQueue.main.async` while the part
/// span is ended immediately afterwards on the calling thread, so a notification observer has no
/// ordering guarantee at all and — when the caller is already on main — is guaranteed to run after
/// the part span has closed. ``SessionController`` therefore calls this type directly, on the thread
/// that is ending the part, before it ends the part span.
///
/// The registered recorders are snapshotted under the lock and then driven **outside** it. That is
/// deliberate: a recorder can log while closing its span, and the SDK's own logging path runs
/// `LogController.createLog` → `addCurrentStates` → ``logAttributes``, which takes this same lock on
/// the same thread. Since it is non-reentrant, driving recorders under it would trap. See
/// ``StateRecorder``'s threading notes for the full chain.
final class StateCaptureCoordinator {

    private let recorders: EmbraceMutex<[StateRecording]> = EmbraceMutex([])

    /// Registers a recorder and, for eager states, activates it right away.
    ///
    /// Note there is no `unregister`: a recorder owns its state's history for the lifetime of the
    /// SDK. Any remote-config gate must therefore be evaluated *before* registering, because once
    /// registered a recorder will open a span on every subsequent part.
    ///
    /// - Parameters:
    ///   - recorder: The recorder to drive. Held strongly — the coordinator owns the state history
    ///     independently of whichever capture service created it.
    ///   - sessionSpan: The live session part span, if a part is already running. An already-ended
    ///     span is rejected by the recorder, so a boundary racing this call cannot bind the recorder
    ///     to a dead part.
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
    /// Must run after the part is published and before any transition can be reported against it,
    /// otherwise a change arriving in the gap is counted as having happened outside a part.
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

    /// `emb.state.<name>` stamps for every currently active state, for inclusion in log metadata.
    ///
    /// The stamps are gathered per recorder rather than atomically across all of them, so a log can
    /// in principle see one state's new value alongside another's old one. That is acceptable for
    /// telemetry and must not be "fixed" by holding a lock across the recorders — see the note on
    /// this type.
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
