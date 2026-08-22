//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// A single profiling sample containing a stack trace captured at a point in time.
///
/// Frame addresses are stored in a flat array shared across all samples in a
/// ``ProfilingResult``. Use ``frameRange`` to index into that array, or use
/// ``ProfilingResult/frames(for:)`` for convenient per-sample access.
/// Run state of the sampled (main) thread at the moment a sample was captured.
///
/// Raw values mirror the Mach `TH_STATE_*` constants (and the C
/// `emb_thread_run_state_t`). `.unknown` (255) means the state could not be
/// captured (e.g. `thread_info` failed).
public enum ThreadState: UInt8, Sendable {
    case running = 1
    case stopped = 2
    case waiting = 3
    case uninterruptible = 4
    case halted = 5
    case unknown = 255
}

public struct ProfilingSample: Equatable, Hashable, Sendable {
    /// `CLOCK_MONOTONIC_RAW` timestamp in nanoseconds when this sample was captured.
    public let timestamp: UInt64

    /// Index range into the shared frames array for this sample's return addresses.
    public let frameRange: Range<Int>

    /// Run state of the sampled thread when this sample was captured.
    public let threadState: ThreadState

    init(timestamp: UInt64, frameRange: Range<Int>, threadState: ThreadState) {
        self.timestamp = timestamp
        self.frameRange = frameRange
        self.threadState = threadState
    }
}

/// Container for profiling results that couples samples with their frame data.
///
/// Each ``ProfilingSample`` in ``samples`` has a ``ProfilingSample/frameRange``
/// that indexes into the shared ``frames`` array. Use ``frames(for:)`` for
/// convenient access per sample.
///
/// - Important: The ``ProfilingSample/frameRange`` values are only meaningful
///   relative to **this** result's ``frames`` array. Do not use them with
///   frames from a different retrieval.
public struct ProfilingResult: Equatable, Hashable, Sendable {
    /// The profiling samples in chronological order.
    public let samples: [ProfilingSample]

    /// Flat buffer of return addresses shared across all samples.
    public let frames: [UInt]

    /// Access the frame addresses for a specific sample.
    public func frames(for sample: ProfilingSample) -> ArraySlice<UInt> {
        frames[sample.frameRange]
    }

    init(samples: [ProfilingSample], frames: [UInt]) {
        self.samples = samples
        self.frames = frames
    }
}
