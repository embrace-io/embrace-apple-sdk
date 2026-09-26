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

        /// Key stamped beside ``logAttributeKey(for:)`` carrying that value's type, e.g.
        /// `emb.state.screen-automatic.value_type`. Omitted when the value has no type.
        public static func logValueTypeAttributeKey(for stateName: String) -> String {
            "\(logAttributeKey(for: stateName))\(valueTypeSuffix)"
        }

        /// Value of the state when its span was opened, carried over from the previous session part.
        /// Written at span start.
        public static let keyInitialValue = "emb.state.initial_value"

        /// Number of *recorded* transition events, written when the span closes. Always present: a
        /// part in which the state never changed reports `0`.
        public static let keyTransitionCount = "emb.state.transition_count"

        /// The state's new value. Always present on a `transition` event.
        public static let keyNewValue = "emb.state.new_value"

        /// The *type* of the value written beside it: ``keyInitialValue`` on the span,
        /// ``keyNewValue`` on a `transition` event.
        ///
        /// Two values spelled the same are the same value only when their types match — an app
        /// screen named "Backgrounded" is not the ``valueTypeSystem`` value of that name.
        /// **Omitted** when the value has no type, which is the common case.
        public static let keyValueType = "emb.state.value_type"

        /// Value of ``keyValueType`` for values the SDK itself sets, rather than ones derived from
        /// the app.
        public static let valueTypeSystem = "system"

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
        /// matters most for the keys that are omitted rather than written empty — the counters when
        /// zero, and ``keyValueType`` when the value has no type. Nothing else would overwrite a
        /// forged one of those.
        public static func isReserved(_ key: String) -> Bool {
            key.hasPrefix(keyPrefix)
        }

        private static let keyPrefix = "emb.state."

        /// Turns the key a value is stored under into the key its type is stored under. Only the
        /// log stamp needs it — on a span the value's key is fixed, so ``keyValueType`` is literal.
        private static let valueTypeSuffix = ".value_type"
    }
}
