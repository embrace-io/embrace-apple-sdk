//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let smoothness = EmbraceType(performance: "smoothness")
}

extension SpanSemantics {
    /// Smoothness attribute keys, written onto the foreground session part and onto each
    /// `emb-screen-view`. Matches Android's `emb.smoothness` semconv.
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
