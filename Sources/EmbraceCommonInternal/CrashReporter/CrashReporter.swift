//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Run State

/// Describes the termination state of the previous app run.
public enum LastRunState: Int {
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
public struct CrashReporterInfoKey {
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
package protocol CrashReporter {

    /// Installs crash handlers and initializes storage.
    ///
    /// - Parameter context: Implementation-defined installation parameters.
    /// - Throws: An error if installation fails (e.g., storage not writable, handler setup failed).
    func install(context: CrashReporterContext) throws

    /// Asynchronously fetches crash reports that have not yet been sent/processed.
    ///
    /// - Note: The completion is invoked on an arbitrary queue. If you need main-thread work, hop explicitly.
    /// - Parameter completion: Called with zero or more `EmbraceCrashReport` instances.
    func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void)

    /// Optional callback fired each time a new crash report becomes available after installation.
    ///
    /// - Important: The callback may be invoked on a background queue.
    var onNewReport: ((EmbraceCrashReport) -> Void)? { get set }

    /// Returns the prior run’s termination state.
    ///
    /// - Returns: A `LastRunState` reflecting whether the previous run crashed or exited cleanly.
    func getLastRunState() -> LastRunState

    /// Deletes a crash report from local storage.
    ///
    /// Call this after you have successfully uploaded/processed the report to prevent reprocessing.
    /// - Parameter report: The report to delete.
    func deleteCrashReport(_ report: EmbraceCrashReport)

    /// When `true`, the reporter will not register MetricKit crash payload handling.
    ///
    /// - Discussion: Use this to avoid double-reporting when another component owns MetricKit handling.
    var disableMetricKitReports: Bool { get }

    /// Attaches a string value to the crash context under a custom key.
    ///
    /// - Parameters:
    ///   - key: A short, namespaced key (e.g., `CrashReporterInfoKey.sessionId`).
    ///   - value: A value to record. Pass `nil` to remove a previously stored value.
    ///
    /// - Important: Keys and values should be small. Avoid high-cardinality or PII.
    func appendCrashInfo(key: String, value: String?)

    /// Retrieves a previously stored crash info value.
    ///
    /// - Parameter key: The key previously used in `appendCrashInfo(key:value:)`.
    /// - Returns: The stored value or `nil` if absent.
    func getCrashInfo(key: String) -> String?

    /// Root directory used by the crash reporter for on-disk artifacts, if applicable.
    ///
    /// - Note: Useful for debugging and diagnostics. Not all implementations persist to disk.
    var basePath: String? { get }
}
