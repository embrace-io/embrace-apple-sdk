//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Why a transition was or was not written to the span.
///
/// The two failure cases are kept apart because they mean different things on the wire: a closed
/// span means the change happened outside a part, a dropped event means we discarded it.
enum StateTransitionOutcome {

    /// The `transition` event was written.
    case recorded

    /// The span was already closed — the part was torn down underneath the caller.
    case spanEnded

    /// The span accepted no event, e.g. a conformance that enforces per-span event limits.
    case eventDropped
}

/// One state's recording within one session part: the handle to the open `emb-state-<name>` span.
/// Created when a part starts, discarded when it ends, never reused across parts.
///
/// Performs its span I/O **outside** ``StateRecorder``'s lock, so it owns no mutable accounting —
/// the recorder decides what to write and passes it in.
final class StateSpanToken {

    let span: EmbraceSpan

    init(span: EmbraceSpan) {
        self.span = span
    }

    /// Whether this token's span is still open and able to accept transitions.
    var isRecording: Bool {
        span.endTime == nil
    }

    /// Records a transition event and updates the running transition count.
    ///
    /// - Parameters:
    ///   - value: Serialized new value of the state.
    ///   - time: When the change was *observed*, never when it was processed.
    ///   - count: Running number of recorded transitions, decided by the recorder under its lock.
    ///   - attributes: Attributes supplied from **outside** the SDK. Unlike everything else written
    ///     here they are untrusted, and are filtered and bounded before use.
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

        var eventAttributes = Self.bounded(attributes)
        eventAttributes.merge(flushed.attributes) { _, builtIn in builtIn }
        eventAttributes[SpanSemantics.State.keyNewValue] = value

        // Internal spans bypass the customer-facing per-span event limit (see
        // `StateRecorderLimitsTests`). The nil check covers the `EmbraceSpan` contract, which
        // permits a conformance to drop the event.
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

    /// Filters and bounds attributes that came from outside the SDK.
    ///
    /// State spans are internal, and `isInternal` skips sanitization — an exemption written when
    /// every attribute here was the SDK's own. A public API taking caller attributes changes that,
    /// so the sanitizer is applied by hand. Note it drops non-`String` values.
    ///
    /// The reserved filter runs first rather than relying on the later merge to overwrite: the
    /// counter keys are omitted when zero, so a forged `emb.state.not_in_session` would survive on
    /// any event without counts.
    private static func bounded(_ callerAttributes: EmbraceAttributes) -> EmbraceAttributes {
        let allowed = callerAttributes.filter { !SpanSemantics.State.isReserved($0.key) }
        return sanitizer.sanitizeSpanEventAttributes(allowed)
    }

    /// Default-constructed, which is the only way the handler ever builds one. If its limits become
    /// configurable, thread that instance in here rather than letting this one keep its own.
    private static let sanitizer = DefaultOtelSignalsSanitizer()

    /// Writes the transition count and any residual counts onto the span, then closes it.
    ///
    /// - Parameters:
    ///   - time: When the part ended.
    ///   - flushed: Unrecorded-transition counts that never made it onto an event.
    ///   - count: Total recorded transitions, read by the recorder under its lock.
    /// - Returns: `false` if the span had already ended, in which case nothing was written and the
    ///   caller must retain those counts rather than discarding them.
    @discardableResult
    func end(at time: Date, flushing flushed: UnrecordedTransitions, count: Int) -> Bool {
        guard isRecording else {
            return false
        }

        span.setAttribute(
            key: SpanSemantics.State.keyTransitionCount,
            value: String(count)
        )

        for (key, value) in flushed.attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(endTime: time)
        return true
    }
}
