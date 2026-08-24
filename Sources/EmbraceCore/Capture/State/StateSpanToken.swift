//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// One state's recording within one session part: the handle to the open `emb-state-<name>` span.
///
/// A token is created when a session part starts and discarded when it ends; it is never reused
/// across parts. All access is serialized by the owning ``StateRecorder``, so this type does no
/// locking of its own.
final class StateSpanToken {

    let span: EmbraceSpan

    /// Number of transitions recorded on this span so far. Doubles as the per-part budget counter.
    private(set) var transitionCount: Int = 0

    init(span: EmbraceSpan) {
        self.span = span
    }

    /// Whether this token's span is still open and able to accept transitions.
    var isRecording: Bool {
        span.endTime == nil
    }

    /// Records a transition event and bumps the span's transition count.
    ///
    /// - Parameters:
    ///   - value: Serialized new value of the state.
    ///   - time: When the change was *observed*, never when it was processed.
    ///   - attributes: Optional caller-supplied attributes for this transition.
    ///   - flushed: Unrecorded-transition counts to attach to this event.
    /// - Returns: `false` if the span already ended — the session part was torn down underneath the
    ///   caller and the transition must be recycled rather than dropped.
    func recordTransition(
        value: String,
        at time: Date,
        attributes: EmbraceAttributes,
        flushing flushed: UnrecordedTransitions
    ) -> Bool {
        guard isRecording else {
            return false
        }

        // Strip the reserved namespace from caller attributes rather than just letting the keys we
        // write overwrite them: the counter keys are omitted when their count is zero, so merging
        // alone would let a forged `emb.state.not_in_session` through on any event without counts.
        var eventAttributes = attributes.filter { !SpanSemantics.State.isReserved($0.key) }
        eventAttributes.merge(flushed.attributes) { _, builtIn in builtIn }
        eventAttributes[SpanSemantics.State.keyNewValue] = value

        span.addEvent(
            name: SpanSemantics.State.transitionEventName,
            type: nil,
            timestamp: time,
            attributes: eventAttributes
        )

        transitionCount += 1
        span.setAttribute(
            key: SpanSemantics.State.keyTransitionCount,
            value: String(transitionCount)
        )

        return true
    }

    /// Writes any residual counts onto the span and closes it.
    func end(at time: Date, flushing flushed: UnrecordedTransitions) {
        guard isRecording else {
            return
        }

        for (key, value) in flushed.attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(endTime: time)
    }
}
