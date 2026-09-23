//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension SpanSemantics {
    /// Attribute keys and values for state spans.
    ///
    /// A "state" is a named, continuously-valued signal (the current screen, the network status, the
    /// power mode) whose history is recorded as one span per session part, carrying one `transition`
    /// event per recorded change.
    ///
    /// These keys are a wire contract: renaming or extending them needs a matching change downstream.
    /// Two omissions are deliberate rather than oversights — there is no `max_enforced` key, and
    /// state spans are not private. Cap overflow is counted in ``keyDroppedByInstrumentation``.
    public struct State {
        /// Name of the span recording one state's history, e.g. `emb-state-screen-automatic`.
        public static func spanName(for stateName: String) -> String {
            "emb-state-\(stateName)"
        }

        /// Key stamped on every log while the state is active, e.g. `emb.state.screen-automatic`,
        /// carrying that state's current value.
        public static func logAttributeKey(for stateName: String) -> String {
            "\(keyPrefix)\(stateName)"
        }

        /// Value of the state when its span was opened, carried over from the previous session part.
        /// Written at span start.
        public static let keyInitialValue = "emb.state.initial_value"

        /// Number of *recorded* transition events, written when the span closes. Always present: a
        /// part in which the state never changed reports `0`.
        public static let keyTransitionCount = "emb.state.transition_count"

        /// The state's new value. Always present on a `transition` event.
        public static let keyNewValue = "emb.state.new_value"

        /// Changes that occurred while no session part existed. Written only when > 0.
        public static let keyNotInSession = "emb.state.not_in_session"

        /// Changes deliberately dropped: duplicates of the current value, cap overflow, and
        /// caller-declared coalesced changes. Written only when > 0.
        public static let keyDroppedByInstrumentation = "emb.state.dropped_by_instrumentation"

        /// Name of the span event recording a single state transition. Deliberately un-prefixed —
        /// it lives on an `emb-`-prefixed span, and this literal is what is matched downstream.
        public static let transitionEventName = "transition"

        /// `emb.link_type` on the session part span's link to a state span — how a part's state
        /// spans are found.
        public static let linkType = "STATE"

        /// Whether `key` lies in the reserved `emb.state.*` namespace.
        ///
        /// Caller attributes are filtered through this so they cannot forge a contract key. It
        /// matters most for the counter keys: they are absent when zero, so nothing else would
        /// overwrite a forged one.
        public static func isReserved(_ key: String) -> Bool {
            key.hasPrefix(keyPrefix)
        }

        private static let keyPrefix = "emb.state."
    }
}
