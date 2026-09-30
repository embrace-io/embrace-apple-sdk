//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Monotonic time source used for interval measurement across the SDK.
///
/// Readings count from an arbitrary origin, cannot be adjusted by the user or by time
/// synchronization, and continue to advance while the device is asleep. A value is only meaningful
/// relative to another reading from this same source taken within the same boot: it is not a
/// wall-clock time and must never be converted to one or serialized as one.
///
/// Use this to measure how much time passed between two points. Use `Date` when the value has to
/// describe *when* something happened.
public enum EmbraceMonotonicTime {

    /// Nanoseconds elapsed since an arbitrary origin.
    ///
    /// Backed by `CLOCK_MONOTONIC_RAW`, which keeps advancing while the device is asleep and is
    /// unaffected by frequency adjustments made to the system clock. The sleep behavior is the
    /// reason this is not `CLOCK_UPTIME_RAW`: an app that spends most of the day suspended would
    /// otherwise measure intervals far shorter than the time that actually passed.
    ///
    /// Inlined because it is called from the main-thread stall sampler, which uses back-to-back
    /// readings to measure its own overhead — an out-of-line call would inflate the very number it
    /// is trying to report. The implementation stays allocation-free and lock-free so it remains
    /// safe to call from a sampling thread.
    @inlinable
    @inline(__always)
    public static func nanos() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    }
}
