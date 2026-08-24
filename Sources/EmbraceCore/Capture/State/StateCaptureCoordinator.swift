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
/// This exists because state spans have to be opened and closed *synchronously* at the part
/// boundary: the `embraceSessionPartWillEnd` notification is posted asynchronously and the session
/// span is closed immediately afterwards, so a notification observer would always run too late for
/// the state span to be closed inside the part and linked from it. ``SessionController`` therefore
/// calls this type directly, inside the same critical section that opens and closes the part.
final class StateCaptureCoordinator {

    private let recorders: EmbraceMutex<[StateRecording]> = EmbraceMutex([])

    /// Registers a recorder and, for eager states, activates it right away.
    ///
    /// - Parameters:
    ///   - recorder: The recorder to drive. Held strongly — the coordinator owns the state history
    ///     for the lifetime of the SDK, independent of whichever capture service created it.
    ///   - sessionSpan: The live session part span, if a part is already running.
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

    /// `emb.state.<name>` stamps for every currently active state, for inclusion in log metadata.
    var logAttributes: EmbraceAttributes {
        var attributes: EmbraceAttributes = [:]
        for recorder in recorders.safeValue {
            guard let attribute = recorder.logAttribute else {
                continue
            }
            attributes[attribute.key] = attribute.value
        }
        return attributes
    }
}
