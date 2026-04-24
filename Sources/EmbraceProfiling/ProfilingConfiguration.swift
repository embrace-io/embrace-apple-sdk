//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Configuration for the profiling engine.
///
/// All properties have sensible defaults. Pass a custom configuration to
/// ``ProfilingEngine/start(configuration:)`` to override.
public struct ProfilingConfiguration: Sendable {
    /// Sampling interval in milliseconds.
    /// Recommend: 100ms
    /// Minimum: 10ms
    public let samplingIntervalMs: UInt32

    /// Minimum sampling interval when recovering from drift (ms).
    /// Prevents back-to-back sampling from starving the main thread.
    /// Recommend: around 10% of samplingIntervalMs
    public let minSamplingIntervalMs: UInt32

    /// Maximum number of frames to capture per sample.
    /// The C layer enforces a hard cap of 1024.
    /// Recommend: 500
    public let maxFramesPerSample: UInt32

    /// Ring buffer capacity in bytes (rounded up to a page boundary).
    /// Less than 128k and you'll get massive churn.
    /// More than 10M and you'll be wasting RAM.
    /// Recommend: 1-5 MB
    public let bufferCapacityBytes: UInt32

    public init(
        samplingIntervalMs: UInt32 = 100,
        minSamplingIntervalMs: UInt32 = 10,
        maxFramesPerSample: UInt32 = 500,
        bufferCapacityBytes: UInt32 = 1024 * 1024
    ) {
        self.samplingIntervalMs = samplingIntervalMs
        self.minSamplingIntervalMs = minSamplingIntervalMs
        self.maxFramesPerSample = maxFramesPerSample
        self.bufferCapacityBytes = bufferCapacityBytes
    }

    var isValid: Bool {
        samplingIntervalMs > 0
            && minSamplingIntervalMs > 0
            && minSamplingIntervalMs < samplingIntervalMs / 2
            && maxFramesPerSample > 0
            && maxFramesPerSample <= 1024 // EMB_MAX_STACK_FRAMES
            && bufferCapacityBytes > 128 * 1024
            && bufferCapacityBytes <= 10_485_760 // 10 MB
    }
}
