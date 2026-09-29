//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let smoothness = EmbraceType(performance: "smoothness")
}

extension SpanSemantics {
    /// Attribute keys for smoothness spans. Matches Android's `emb.smoothness` semconv.
    public struct Smoothness {
        public static let name = "smoothness"

        /// Display link ticks (vsyncs) while the span was open, not frames the app rendered. An idle
        /// screen still counts at the display's refresh rate. Android's `frame_count` only counts rendered
        /// frames, so ratios against it are not comparable across platforms.
        public static let keyFrameCount = "smoothness.frame_count"

        /// Total late time while the span was open, in 60fps reference frames. On iOS this is main-thread
        /// lateness only: frames missed in the commit, render server, or GPU while the main thread was
        /// free are not counted, unlike Android, which includes render time.
        public static let keyNormalizedDroppedFrames = "smoothness.normalized_dropped_frames"

        /// Main-thread hangs while the span was open: frames later than the hang threshold, each of which
        /// had its contribution to `keyNormalizedDroppedFrames` capped. Counts every stall, including ones
        /// past `HangLimits.hangPerSession` that emit no hang span. iOS-only.
        public static let keyHangCount = "smoothness.hang_count"

        /// Most severe device thermal state observed while the span was open. iOS-only; one of the
        /// `ThermalState` values.
        public static let keyPeakThermalState = "smoothness.peak_thermal_state"

        /// Whether the span's metrics cover its whole duration. `false` from the moment the span opens,
        /// and set to `true` only when the span ends normally. A span still `false` was recovered after
        /// the app was killed or crashed, so its metrics are only as fresh as `keyCheckpointTime`, or
        /// missing if no checkpoint was written. iOS-only.
        public static let keyComplete = "smoothness.complete"

        /// When the metrics on the span were last written while it was open, in nanoseconds since 1970.
        /// On an incomplete span, the metrics cover the span's start up to this time, not up to its end
        /// time. iOS-only.
        public static let keyCheckpointTime = "smoothness.checkpoint_time"

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
