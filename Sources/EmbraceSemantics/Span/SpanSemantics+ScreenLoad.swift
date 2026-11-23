//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let screenLoad = EmbraceType(performance: "screen_load")
}

extension SpanSemantics {
    /// Attribute keys and values for the screen-load vital: the time from the user's tap (or the
    /// navigation itself, when there was no tap) until the destination screen is loaded.
    ///
    /// These names, keys and values are a cross-platform wire contract shared with the Android SDK
    /// (`EmbScreenLoadAttributes`, `SchemaType.ScreenLoad`): renaming or extending them needs a
    /// matching change on Android and downstream. The destination's name is written to
    /// ``SpanSemantics/View/keyViewName``.
    public struct ScreenLoad {
        /// Name of the screen-load span. Deliberately not `emb-`-prefixed like other iOS spans,
        /// because Android emits this exact name.
        public static let name = "screen-load"

        /// How the screen load ended. One of the `outcome*` values.
        public static let keyOutcome = "screen_load.outcome"

        /// Duration from the initial interaction until the navigation start event, in milliseconds.
        /// `0` when there was no tap.
        public static let keyNavStartDelayMs = "screen_load.nav_start_delay_ms"

        /// Duration from the navigation start event until the navigation end event, in milliseconds.
        public static let keyNavDurationMs = "screen_load.nav_duration_ms"

        /// Duration from the navigation end event until the first frame rendered on the destination,
        /// in milliseconds. `0` if no frame arrived before the load completed.
        public static let keyFirstFrameDurationMs = "screen_load.first_frame_duration_ms"

        /// The idle threshold that was applied to determine when the destination screen had settled.
        /// Always `0` on iOS, which has no settle detection yet.
        public static let keyIdleThresholdMs = "screen_load.idle_threshold_ms"

        /// The maximum duration that was applied before the screen load was force-reported as timed out.
        public static let keyTimeoutMs = "screen_load.timeout_ms"

        /// The maximum tap-to-navigation-start gap that was applied to link the two events into one
        /// screen load.
        public static let keyNavTimeoutMs = "screen_load.nav_timeout_ms"

        /// The destination went quiet for the idle threshold within the timeout. Not emitted on iOS
        /// until settle detection exists.
        public static let outcomeSettled = "settled"

        /// The load ended at the first frame after navigation end, or at navigation end when no frame
        /// arrived within the timeout. iOS's normal outcome, since it has no settle detection.
        public static let outcomeTimedOut = "timed_out"

        /// The user tapped again after navigation end, before the load completed.
        public static let outcomeUserInterrupted = "user_interrupted"

        /// A new navigation started after navigation end, before the load completed.
        public static let outcomeNavigationInterrupted = "navigation_interrupted"
    }
}
