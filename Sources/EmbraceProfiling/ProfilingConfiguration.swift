//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Internal configuration for the profiling engine.
struct ProfilingConfiguration {
    /// Sampling interval in milliseconds.
    let samplingIntervalMs: UInt32 = 100

    /// Maximum number of frames to capture per sample.
    let maxFramesPerSample: UInt32 = 512

    /// Ring buffer capacity in bytes.
    let bufferCapacityBytes: UInt32 = 1_048_576
}
