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
    /// These keys are the cross-platform wire contract and are shared with the Android SDK — they
    /// must not be renamed or extended without a corresponding change there. In particular there is
    /// deliberately **no** `emb.state.max_enforced` key and state spans are **not** private: when a
    /// transition is dropped because the per-part cap was reached, it is counted silently in
    /// ``keyDroppedByInstrumentation``.
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

        /// Running count of *recorded* transition events. Re-set on the span after each transition.
        public static let keyTransitionCount = "emb.state.transition_count"

        /// The state's new value. Always present on a `transition` event.
        public static let keyNewValue = "emb.state.new_value"

        /// Count of changes that occurred while no session part existed. Written only when > 0,
        /// either onto the next recorded transition or onto the span at close.
        public static let keyNotInSession = "emb.state.not_in_session"

        /// Count of changes deliberately dropped by the instrumentation — duplicates of the current
        /// value, per-part cap overflow, and caller-declared coalesced changes. Written only when
        /// > 0, either onto the next recorded transition or onto the span at close.
        public static let keyDroppedByInstrumentation = "emb.state.dropped_by_instrumentation"

        /// Name of the span event recording a single state transition.
        ///
        /// Deliberately un-prefixed: the event lives on an `emb-`-prefixed internal span, and this
        /// literal is the cross-platform contract.
        public static let transitionEventName = "transition"

        /// `emb.link_type` value used on the session part span's link to a state span. This is how
        /// the backend finds the state spans belonging to a part.
        public static let linkType = "STATE"

        /// Whether `key` lies in the reserved `emb.state.*` namespace.
        ///
        /// Caller-supplied transition attributes are filtered through this so they can never forge
        /// a contract key — including the counter keys, which are absent from the payload when their
        /// count is zero and would otherwise slip through unnoticed.
        public static func isReserved(_ key: String) -> Bool {
            key.hasPrefix(keyPrefix)
        }

        private static let keyPrefix = "emb.state."
    }
}
