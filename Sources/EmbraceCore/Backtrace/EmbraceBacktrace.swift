//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A single frame in a captured backtrace.
///
/// A frame optionally contains symbolication information (`symbol`) and the
/// binary image that owns the address (`image`). When symbolication is not
/// available (or deferred), only the raw `address` will be present.
public struct EmbraceBacktraceFrame: Codable {
    /// The program counter (return address) captured for this frame.
    ///
    /// This is an absolute virtual address in the target process at the time of capture.
    /// Symbolication may adjust this value (e.g., `returnAddress - 1`) internally, but the
    /// stored `address` here reflects the captured PC used to resolve symbols.
    public let address: UInt64

    /// Symbolication information for a frame, if available.
    public struct Symbol: Codable {
        /// The starting address of the resolved symbol (function/method).
        ///
        /// This is typically the symbol’s load address in process space.
        public let address: UInt

        /// The demangled symbol name (e.g., Swift or C/Obj-C function).
        public let name: String
    }
    /// Symbolication information, if the address has been resolved to a symbol.
    ///
    /// This will be `nil` for unsymbolicated frames.
    public let symbol: Symbol?

    /// Metadata about the binary image that owns the frame address, if known.
    public struct Image: Codable {
        /// The image UUID (Mach-O UUID / LC_UUID) as a string.
        public let uuid: String

        /// The short image name (e.g., process name or dylib name).
        public let name: String

        /// The image’s load address (base address) in process space.
        public let address: UInt

        /// The mapped size of the image in bytes.
        public let size: UInt64
    }
    /// The binary image that contains `address`, if it could be resolved.
    public let image: Image?
}
extension EmbraceBacktraceFrame: Sendable {}
extension EmbraceBacktraceFrame.Symbol: Sendable {}
extension EmbraceBacktraceFrame.Image: Sendable {}

/// A single thread’s captured call stack.
public struct EmbraceBacktraceThread: Codable {
    /// The 0-based index of the thread in the capture.
    ///
    /// This is the index assigned during snapshotting and is not guaranteed
    /// to equal the system thread ID (tid) or pthread ID.
    public let index: Int

    /// Returns the frames for this thread, optionally symbolicated.
    ///
    /// - Parameter symbolicated: When `true`, attempts to return frames with symbol and image
    ///   information attached (if available in the symbolication context). When `false`, returns
    ///   raw frame addresses only.
    /// - Returns: An array of frames in top-of-stack → bottom-of-stack order.
    ///
    /// - Note: Symbolication requires image metadata and symbol tables to be present.
    ///   If symbolication is unavailable, `symbol`/`image` may remain `nil` even when
    ///   `symbolicated == true`.
    public func frames(symbolicated: Bool) -> [EmbraceBacktraceFrame] {
        callstack.frames(symbolicated: symbolicated)
    }

    /// Raw call stack storage for a thread.
    ///
    /// This internal type keeps the minimal data needed to reconstruct frames
    /// and defer symbolication to a later stage to avoid doing heavy work on
    /// crash/hang-sensitive paths.
    internal struct Callstack: Codable {
        /// Return addresses (program counters) captured for this thread.
        ///
        /// Addresses are stored as process-absolute virtual addresses.
        let addresses: [UInt]

        /// Number of valid frames in `addresses`.
        ///
        /// This may be ≤ `addresses.count`; callers should prefer `count` when
        /// reconstructing the stack to avoid partially filled buffers.
        let count: Int
    }

    /// The raw call stack for this thread.
    internal let callstack: Callstack
}
extension EmbraceBacktraceThread: Sendable {}
extension EmbraceBacktraceThread.Callstack: Sendable {}

/// Units used by the backtrace timestamp.
public enum EmbraceBacktraceTimestampUnits: String, Codable {
    /// Timestamp represents nanoseconds.
    case nanoseconds
    /// Timestamp represents milliseconds.
    case milliseconds
}
extension EmbraceBacktraceTimestampUnits: Sendable {}

/// A snapshot of one or more threads’ call stacks at a moment in time.
///
/// The snapshot includes the capture `timestamp` and its `timestampUnits` so
/// that multiple captures can be ordered and correlated with other telemetry.
public struct EmbraceBacktrace: Codable {
    /// Units for `timestamp`.
    public let timestampUnits: EmbraceBacktraceTimestampUnits

    /// The capture timestamp, measured using a monotonic clock.
    ///
    /// This value is intended for relative ordering and duration measurements.
    /// It is not wall-clock time.
    public let timestamp: UInt64

    /// The set of threads captured in this snapshot.
    public let threads: [EmbraceBacktraceThread]

    // MARK: - Capture

    /// Captures a backtrace for the specified `pthread_t`.
    ///
    /// This API is appropriate for capturing a thread other than the current one,
    /// such as a suspected hang target.
    ///
    /// - Parameters:
    ///   - thread: The pthread whose stack should be captured.
    ///   - suspendingThreads: When `true`, suspends the target thread while
    ///     unwinding to obtain a consistent snapshot. When `false`, captures
    ///     without suspension for lower impact at the cost of potential minor
    ///     inconsistencies if the thread is mutating registers concurrently.
    /// - Returns: A backtrace snapshot containing exactly one `EmbraceBacktraceThread`.
    ///
    /// - Important: Suspending threads can have performance and liveness implications,
    ///   especially if taken on hot paths or under locks. Use with care in production.
    /// - Note: The `timestamp` is sourced from `CLOCK_MONOTONIC_RAW` via
    ///   `clock_gettime_nsec_np`, which is suitable for measuring intervals.
    static func backtrace(of thread: pthread_t, suspendingThreads: Bool) -> EmbraceBacktrace {
        EmbraceBacktrace(
            timestampUnits: .nanoseconds,
            timestamp: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW),
            threads: takeSnapshot(of: thread, suspendingThreads: suspendingThreads)
        )
    }

    /// Captures a backtrace of the current thread using `Thread.callStackReturnAddresses`.
    ///
    /// This is the simplest capture path and does not require suspending any threads.
    /// It’s useful for lightweight diagnostics or when called on the thread of interest.
    ///
    /// - Returns: A backtrace snapshot containing one `EmbraceBacktraceThread`
    ///   derived from `Thread.callStackReturnAddresses`.
    ///
    /// - Note: The `timestamp` is sourced from `CLOCK_MONOTONIC_RAW` via
    ///   `clock_gettime_nsec_np`, which is suitable for measuring intervals.
    static func backtrace() -> EmbraceBacktrace {
        EmbraceBacktrace(
            timestampUnits: .nanoseconds,
            timestamp: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW),
            threads: takeSnapshotApple()
        )
    }
}
extension EmbraceBacktrace: Sendable {}

extension EmbraceBacktrace {
    /// Indicates whether backtrace capture is available in the current client configuration.
    ///
    /// This returns `true` if a `Backtracer` instance has been provided in
    /// `Embrace.client?.options`. Otherwise, it returns `false`, meaning
    /// the SDK cannot capture custom stack traces and will rely solely on
    /// system defaults.
    static public var isAvailable: Bool {
        Embrace.client?.options.backtracer != nil
    }
}
