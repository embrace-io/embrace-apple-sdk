//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// A single profiling sample containing a stack trace captured at a point in time.
///
/// Frame addresses are stored in a flat array shared across all samples in a
/// ``ProfilingResult``. Use ``frameRange`` to index into that array, or use
/// ``ProfilingResult/frames(for:)`` for convenient per-sample access.
public struct ProfilingSample: Equatable, Hashable, Sendable {
    /// `CLOCK_MONOTONIC_RAW` timestamp in nanoseconds when this sample was captured.
    public let timestamp: UInt64

    /// Index range into the shared frames array for this sample's return addresses.
    public let frameRange: Range<Int>

    public init(timestamp: UInt64, frameRange: Range<Int>) {
        self.timestamp = timestamp
        self.frameRange = frameRange
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

    public init(samples: [ProfilingSample], frames: [UInt]) {
        self.samples = samples
        self.frames = frames
    }
}
