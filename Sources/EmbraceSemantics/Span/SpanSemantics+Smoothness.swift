//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let smoothness = EmbraceType(performance: "smoothness")
}

extension SpanSemantics {
    /// Smoothness attribute keys, written onto the foreground session part, onto each
    /// `emb-screen-view`, and onto each focal moment span. Matches Android's `emb.smoothness` semconv.
    public struct Smoothness {

        /// Prefix shared by every smoothness attribute key.
        public static let keyPrefix = "smoothness."

        /// Frame intervals the main thread overran, in whole frames at the display's native refresh rate.
        /// On iOS this is main-thread lateness only: frames missed in the commit, render server, or GPU
        /// while the main thread was free are not counted, unlike Android, which includes render time.
        public static let keyDroppedFrames = "smoothness.dropped_frames"

        /// Display link ticks plus dropped frames. An idle screen still counts at the display's refresh
        /// rate; Android only counts rendered frames.
        public static let keyExpectedFrames = "smoothness.expected_frames"

        /// Main-thread hangs in the session part: ticks later than the hang threshold. Counts every stall,
        /// including ones past `HangLimits.hangPerSession` that emit no hang span. iOS-only.
        public static let keyHangCount = "smoothness.hang_count"

        /// Most severe device thermal state observed in the session part. iOS-only; one of the
        /// `ThermalState` values.
        public static let keyPeakThermalState = "smoothness.peak_thermal_state"

        /// Name of the span emitted for each focal moment.
        public static let focalMomentName = "smoothness"

        /// How the focal moment ended; one of the `Outcome` values.
        public static let keyOutcome = "smoothness.outcome"

        /// Display link ticks inside the focal moment. Android counts rendered frames instead.
        public static let keyFrameCount = "smoothness.frame_count"

        /// Total main-thread lateness inside the focal moment, in 60fps reference frames. Uncapped.
        public static let keyNormalizedDroppedFrames = "smoothness.normalized_dropped_frames"

        /// Idle time after the last touch lifts that settles the focal moment, in milliseconds.
        public static let keyIdleThresholdMs = "smoothness.idle_threshold_ms"

        /// Idle time while a touch is held that settles the focal moment, in milliseconds.
        public static let keyHeldIdleThresholdMs = "smoothness.held_idle_threshold_ms"

        /// Values for `keyOutcome`.
        public struct Outcome {
            public static let settled = "settled"
            public static let interrupted = "interrupted"
        }

        /// Values for `keyPeakThermalState`, mirroring `ProcessInfo.ThermalState`.
        public struct ThermalState {
            public static let nominal = "nominal"
            public static let fair = "fair"
            public static let serious = "serious"
            public static let critical = "critical"
            public static let unknown = "unknown"
        }
    }
}
