//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Run State

/// Describes the termination state of the previous app run.
@objc public enum LastRunState: Int {
    /// The previous run state could not be determined (e.g., first launch or missing/invalid metadata).
    case unavailable
    /// The previous run ended in a crash (uncaught exception, signal, abort, watchdog, etc.).
    case crash
    /// The previous run exited cleanly (foreground or background termination initiated by the app/OS without crash).
    case cleanExit
}

// MARK: - Crash Reporter Info Keys

/// Namespaced keys for attaching extra context to crash reports.
///
/// These keys are intended for use with `CrashReporter.appendCrashInfo(key:value:)`
/// and retrieval via `CrashReporter.getCrashInfo(key:)`.
@objc public class CrashReporterInfoKey: NSObject {
    /// Session identifier (e.g., Embrace session id). Value should be a stable string for the lifetime of the session.
    static public let sessionId = "emb-sid"
    /// SDK version string (e.g., "5.2.1"). Use to correlate reports with the runtime SDK build.
    static public let sdkVersion = "emb-sdk"
}

// MARK: - Crash Reporter

/// Collects, persists, and surfaces crash reports for the host application.
///
/// Typical lifecycle:
/// 1. Call `install(context:)` as early as possible during app launch (e.g., in `application(_:didFinishLaunchingWithOptions:)`).
/// 2. Optionally set `onNewReport` to receive reports for crashes detected after installation.
/// 3. On next launch, call `getLastRunState()` to know whether the prior run crashed.
/// 4. Use `fetchUnsentCrashReports(completion:)` to process and upload any pending reports.
/// 5. After successful handling, call `deleteCrashReport(_:)` to remove a report from local storage.
@objc public protocol CrashReporter {

    /// Installs crash handlers and initializes storage.
    ///
    /// - Parameter context: Implementation-defined installation parameters.
    /// - Throws: An error if installation fails (e.g., storage not writable, handler setup failed).
    @objc func install(context: CrashReporterContext) throws

    /// Asynchronously fetches crash reports that have not yet been sent/processed.
    ///
    /// - Note: The completion is invoked on an arbitrary queue. If you need main-thread work, hop explicitly.
    /// - Parameter completion: Called with zero or more `EmbraceCrashReport` instances.
    @objc func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void)

    /// Optional callback fired each time a new crash report becomes available after installation.
    ///
    /// - Important: The callback may be invoked on a background queue.
    @objc var onNewReport: ((EmbraceCrashReport) -> Void)? { get set }

    /// Returns the prior run’s termination state.
    ///
    /// - Returns: A `LastRunState` reflecting whether the previous run crashed or exited cleanly.
    @objc func getLastRunState() -> LastRunState

    /// Deletes a crash report from local storage.
    ///
    /// Call this after you have successfully uploaded/processed the report to prevent reprocessing.
    /// - Parameter report: The report to delete.
    @objc func deleteCrashReport(_ report: EmbraceCrashReport)

    /// When `true`, the reporter will not register MetricKit crash payload handling.
    ///
    /// - Discussion: Use this to avoid double-reporting when another component owns MetricKit handling.
    @objc var disableMetricKitReports: Bool { get }

    /// Attaches a string value to the crash context under a custom key.
    ///
    /// - Parameters:
    ///   - key: A short, namespaced key (e.g., `CrashReporterInfoKey.sessionId`).
    ///   - value: A value to record. Pass `nil` to remove a previously stored value.
    ///
    /// - Important: Keys and values should be small. Avoid high-cardinality or PII.
    @objc func appendCrashInfo(key: String, value: String?)

    /// Retrieves a previously stored crash info value.
    ///
    /// - Parameter key: The key previously used in `appendCrashInfo(key:value:)`.
    /// - Returns: The stored value or `nil` if absent.
    @objc func getCrashInfo(key: String) -> String?

    /// Root directory used by the crash reporter for on-disk artifacts, if applicable.
    ///
    /// - Note: Useful for debugging and diagnostics. Not all implementations persist to disk.
    @objc var basePath: String? { get }
}

// MARK: - Backtracing

/// Machine address type used for frame return/call sites.
///
/// - Note: This is pointer-sized (`UInt`), typically 64-bit on modern Apple platforms.
public typealias FrameAddress = UInt

/// Captures stack backtraces for threads.
@objc public protocol Backtracer {

    /// Captures a backtrace for the provided thread.
    ///
    /// - Parameter thread: The target `pthread_t`. Callers are responsible for ensuring the thread is in a safe state
    ///                     for backtracing (e.g., suspended or the current thread).
    /// - Returns: An array of frame addresses representing the call stack, ordered from the top frame to the bottom.
    ///
    /// - Important: Many symbolication pipelines expect the *call site* rather than the *return address*.
    ///   Implementations commonly transform the raw PC to a canonical call instruction (e.g., `returnAddress - 1` on ARM).
    ///   See `SymbolicatedFrame.callInstruction`.
    @objc func backtrace(of thread: pthread_t) -> [FrameAddress]
}

// MARK: - Symbolication

/// A single symbolicated frame describing where an address resolves within an image.
@objc public class SymbolicatedFrame: NSObject {

    /// Program counter captured at the time of the backtrace (often a “return address”).
    public let returnAddress: FrameAddress

    /// Canonical call-site address used for symbol lookup (often `returnAddress - 1` on ARM).
    ///
    /// - Discussion: Subtracting 1 normalizes to the instruction that performed the call/jump so
    ///   that lookups fall *within* the symbol’s range. Implementations should ensure this is correct
    ///   for the target architecture and unwind source.
    public let callInstruction: FrameAddress

    /// The address of the symbol/function entry point.
    public let symbolAddress: FrameAddress

    /// Resolved demangled symbol name if available (e.g., `MyClass.myMethod(param:)`).
    public let symbolName: String?

    /// The filename of the binary image (e.g., `MyApp`, `UIKitCore`).
    public let imageName: String?

    /// The UUID of the binary image (Mach-O UUID), used to match dSYMs/symbol maps.
    public let imageUUID: String?

    /// The image’s preferred load address (Mach-O base / slide-adjusted).
    public let imageAddress: FrameAddress

    /// The size in bytes of the loaded image.
    public let imageSize: UInt64

    /// Designated initializer for a symbolicated frame.
    ///
    /// - Parameters:
    ///   - returnAddress: Raw return/program-counter address captured from the backtrace.
    ///   - callInstruction: Canonical call-site address for symbolication (often `returnAddress - 1`).
    ///   - symbolAddress: Resolved symbol’s entry address.
    ///   - symbolName: Optional demangled symbol name.
    ///   - imageName: Optional Mach-O image name.
    ///   - imageUUID: Optional UUID string used to match dSYMs.
    ///   - imageAddress: The image base address (slide applied if appropriate).
    ///   - imageSize: The image size in bytes.
    @objc public init(
        returnAddress: FrameAddress,
        callInstruction: FrameAddress,
        symbolAddress: FrameAddress,
        symbolName: String?,
        imageName: String?,
        imageUUID: String?,
        imageAddress: FrameAddress,
        imageSize: UInt64
    ) {
        self.returnAddress = returnAddress
        self.callInstruction = callInstruction
        self.symbolAddress = symbolAddress
        self.symbolName = symbolName
        self.imageName = imageName
        self.imageUUID = imageUUID
        self.imageAddress = imageAddress
        self.imageSize = imageSize
    }
}

/// Resolves raw addresses to human-readable symbols and image metadata.
@objc public protocol Symbolicator {

    /// Resolves a single frame address to symbolic information.
    ///
    /// - Parameter address: A raw program-counter/call-site address. If you captured a return address,
    ///                      consider normalizing (e.g., `addr - 1`) before calling.
    /// - Returns: A `SymbolicatedFrame` on success, or `nil` if the address could not be resolved
    ///            (e.g., missing symbols/dSYMs, unknown image).
    @objc func resolve(address: FrameAddress) -> SymbolicatedFrame?
}

// MARK: - Watchdog Reporting
public struct WatchdogEvent {
    public let timestamp: NanosecondClock
    public let duration: NanosecondClock

    public init(timestamp: NanosecondClock, duration: NanosecondClock) {
        self.timestamp = timestamp
        self.duration = duration
    }
}

public protocol WatchdogReporter: CrashReporter {

    func watchdogEventStarted(_ event: WatchdogEvent)
    func watchdogEventOngoing(_ event: WatchdogEvent)
    func watchdogEventEnded(_ event: WatchdogEvent)
}
