//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Per-frame timing data captured by `FrameRateMonitor`.
///
/// `FrameMetrics` records how late a frame arrived relative to when the system
/// promised it would fire. It is dynamic-rate–safe: `expectedTimestamp` is
/// sourced from the *previous* tick's `targetTimestamp`, so ProMotion, Low
/// Power Mode, and `preferredFrameRateRange` transitions are handled correctly.
///
/// - Note: Not currently wired into hang detection. Intended for future
///   frame-rate telemetry features.
public struct FrameMetrics {

    /// The previous tick's `targetTimestamp` — the system's own promise of
    /// when this frame would fire.
    public let expectedTimestamp: CFTimeInterval

    /// The actual `timestamp` when this frame's callback fired.
    public let actualTimestamp: CFTimeInterval

    /// The nominal frame duration at the time of this tick, reflecting the
    /// current dynamic refresh rate.
    public let nominalFrameDuration: TimeInterval

    /// How late this frame arrived relative to the system's schedule.
    /// Always non-negative.
    public var delay: TimeInterval {
        max(0, actualTimestamp - expectedTimestamp)
    }

    /// The number of frames dropped, estimated from the delay and the nominal
    /// frame duration.
    public var droppedFrameCount: Int {
        guard nominalFrameDuration > 0 else { return 0 }
        return max(0, Int(delay / nominalFrameDuration))
    }
}
