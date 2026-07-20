//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Configuration for the profiling engine.
///
/// All properties have sensible defaults. Pass a custom configuration to
/// ``ProfilingEngine/start(configuration:)`` to override.
public struct ProfilingConfiguration: Equatable, Hashable, Sendable {
    /// Sampling interval in milliseconds.
    /// Recommend: 100ms
    /// Minimum: 10ms
    public let samplingIntervalMs: UInt32

    /// Minimum sampling interval when recovering from drift (ms).
    /// Prevents back-to-back sampling from starving the main thread.
    /// Must be less than 50% of samplingIntervalMs (the actual enforced constraint).
    /// Recommend: around 10% of samplingIntervalMs.
    public let minSamplingIntervalMs: UInt32

    /// Maximum number of frames to capture per sample.
    /// The C layer enforces a hard cap of 1024.
    /// Recommend: 500
    public let maxFramesPerSample: UInt32

    /// Minimum frame count before invoking the fallback stack walker (if configured).
    /// If the primary frame-pointer walk yields fewer than this many frames, the fallback
    /// walker is called while the thread is still suspended.
    /// Set to 0 to disable the fallback walker entirely.
    /// Must be ≤ maxFramesPerSample.
    /// Recommend: 3
    public let minFramesPerSample: UInt32

    /// Ring buffer capacity in bytes (rounded up to a page boundary).
    /// Less than 128k and you'll get massive churn.
    /// More than 10M and you'll be wasting RAM.
    /// Recommend: 1-5 MB
    public let bufferCapacityBytes: UInt32

    /// If `true`, the sampler comes up paused: the worker thread is alive and
    /// waking on cadence, but the suspend+walk+write block is gated until
    /// ``ProfilingEngine/resume()`` is called. Useful when sampling is driven
    /// by external events (e.g. spans) and the engine should be ready to
    /// resume immediately without paying start-up cost.
    public let startPaused: Bool

    public init(
        samplingIntervalMs: UInt32 = 100,
        minSamplingIntervalMs: UInt32 = 10,
        maxFramesPerSample: UInt32 = 500,
        minFramesPerSample: UInt32 = 3,
        bufferCapacityBytes: UInt32 = 1024 * 1024,
        startPaused: Bool = false
    ) {
        self.samplingIntervalMs = samplingIntervalMs
        self.minSamplingIntervalMs = minSamplingIntervalMs
        self.maxFramesPerSample = maxFramesPerSample
        self.minFramesPerSample = minFramesPerSample
        self.bufferCapacityBytes = bufferCapacityBytes
        self.startPaused = startPaused
    }

    var isValid: Bool {
        samplingIntervalMs >= 10
            && minSamplingIntervalMs > 0
            && minSamplingIntervalMs < samplingIntervalMs / 2
            && maxFramesPerSample > 0
            && maxFramesPerSample <= 1024 // EMB_MAX_STACK_FRAMES
            && bufferCapacityBytes > 128 * 1024
            && bufferCapacityBytes <= 10_485_760 // 10 MB
            && minFramesPerSample <= maxFramesPerSample
    }
}
