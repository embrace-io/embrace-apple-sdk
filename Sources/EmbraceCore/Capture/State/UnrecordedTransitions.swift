//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Counts of state changes that happened but were **not** recorded as `transition` events.
///
/// State capture is lossless in aggregate: a change that never becomes an event is still counted
/// here, and the counts ride along with the next event that *is* recorded (or land on the span at
/// close if no further event ever comes). A backend can therefore always reconstruct how many
/// changes occurred, even when the individual events are missing.
struct UnrecordedTransitions: Equatable {

    /// Changes that occurred while no session part was recording.
    var notInSession: Int = 0

    /// Changes the instrumentation dropped on purpose: duplicates of the current value, overflow
    /// past the per-part cap, and coalesced changes the caller declared it had already collapsed.
    var droppedByInstrumentation: Int = 0

    static let none = UnrecordedTransitions()

    var isEmpty: Bool {
        notInSession == 0 && droppedByInstrumentation == 0
    }

    /// Attributes for these counts, omitting any counter that is zero.
    ///
    /// Zero-valued counters are left out rather than written as `"0"` — their absence is what the
    /// wire contract specifies.
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
