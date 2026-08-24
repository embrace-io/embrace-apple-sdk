//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Why a transition was or was not written to the span.
///
/// The two failure cases are distinguished because they mean different things on the wire: a closed
/// span means the change happened outside a recording part, whereas a dropped event means the
/// instrumentation itself discarded it.
enum StateTransitionOutcome {

    /// The `transition` event was written.
    case recorded

    /// The span was already closed — the part was torn down underneath the caller.
    case spanEnded

    /// The span accepted no event, e.g. a conformance that enforces per-span event limits.
    case eventDropped
}

/// One state's recording within one session part: the handle to the open `emb-state-<name>` span.
///
/// A token is created when a session part starts and discarded when it ends; it is never reused
/// across parts.
///
/// The token performs span I/O and is deliberately called **outside** ``StateRecorder``'s lock, so
/// it owns no mutable accounting of its own — the recorder decides what to write and passes it in.
final class StateSpanToken {

    let span: EmbraceSpan

    init(span: EmbraceSpan) {
        self.span = span
    }

    /// Whether this token's span is still open and able to accept transitions.
    var isRecording: Bool {
        span.endTime == nil
    }

    /// Records a transition event and writes the running transition count.
    ///
    /// - Parameters:
    ///   - value: Serialized new value of the state.
    ///   - time: When the change was *observed*, never when it was processed.
    ///   - count: Running number of recorded transitions, decided by the recorder under its lock.
    ///   - attributes: Optional caller-supplied attributes for this transition.
    ///   - flushed: Unrecorded-transition counts to attach to this event.
    func recordTransition(
        value: String,
        at time: Date,
        count: Int,
        attributes: EmbraceAttributes,
        flushing flushed: UnrecordedTransitions
    ) -> StateTransitionOutcome {
        guard isRecording else {
            return .spanEnded
        }

        // Strip the reserved namespace from caller attributes rather than just letting the keys we
        // write overwrite them: the counter keys are omitted when their count is zero, so merging
        // alone would let a forged `emb.state.not_in_session` through on any event without counts.
        var eventAttributes = attributes.filter { !SpanSemantics.State.isReserved($0.key) }
        eventAttributes.merge(flushed.attributes) { _, builtIn in builtIn }
        eventAttributes[SpanSemantics.State.keyNewValue] = value

        // State spans are created internal, so the event bypasses the customer-facing per-span
        // event limit (see `StateRecorderLimitsTests`). The nil check guards the general
        // `EmbraceSpan` contract, which permits a conformance to drop the event.
        guard
            span.addEvent(
                name: SpanSemantics.State.transitionEventName,
                type: nil,
                timestamp: time,
                attributes: eventAttributes
            ) != nil
        else {
            return .eventDropped
        }

        span.setAttribute(
            key: SpanSemantics.State.keyTransitionCount,
            value: String(count)
        )

        return .recorded
    }

    /// Writes any residual counts onto the span and closes it.
    ///
    /// - Returns: `false` if the span had already ended, in which case `flushed` was **not** written
    ///   and the caller must retain those counts rather than discarding them.
    @discardableResult
    func end(at time: Date, flushing flushed: UnrecordedTransitions) -> Bool {
        guard isRecording else {
            return false
        }

        for (key, value) in flushed.attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(endTime: time)
        return true
    }
}
