//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// A single profiling sample containing a stack trace captured at a point in time.
public struct ProfilingSample {
    /// `CLOCK_MONOTONIC_RAW` timestamp in nanoseconds when this sample was captured.
    public let timestamp: UInt64

    /// Raw return addresses from the captured stack trace.
    public let frames: [UInt]

    public init(timestamp: UInt64, frames: [UInt]) {
        self.timestamp = timestamp
        self.frames = frames
    }
}
