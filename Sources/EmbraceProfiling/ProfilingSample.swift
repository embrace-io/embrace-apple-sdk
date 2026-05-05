//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// How a stack trace was captured.
public enum StackUnwindMethod: Equatable, Hashable, CaseIterable, Sendable {
    /// Frame-pointer based stack walking (fast, works when FP is available)
    case framePointer
    /// KSCrash's DWARF-based unwinder (slower, more robust fallback)
    case kscrash
    /// Partial frame-pointer walk (below minFPFrames threshold, returned as last resort if kscrash returned nothing)
    case framePointerPartial
    /// Stack capture failed entirely — no frames were obtained.
    case failed
}

/// A single profiling sample containing a stack trace captured at a point in time.
public struct ProfilingSample: Equatable, Hashable, Sendable {
    /// `CLOCK_MONOTONIC_RAW` timestamp in nanoseconds when this sample was captured.
    public let timestamp: UInt64

    /// Raw return addresses from the captured stack trace.
    public let frames: [UInt]

    /// The method used to capture this stack trace.
    public let unwindMethod: StackUnwindMethod

    public init(timestamp: UInt64, frames: [UInt], unwindMethod: StackUnwindMethod) {
        self.timestamp = timestamp
        self.frames = frames
        self.unwindMethod = unwindMethod
    }
}
