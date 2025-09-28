//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension Notification.Name {

    /// Notification sent when the crash reporter has completed sending crash reports.
    /// The `object` of the notification is an array of `EmbraceCrashReport`, ie: `[EmbraceCrashReport]`.
    public static let embraceDidSendCrashReports = Notification.Name("embrace.did.send.crash.reports")
}

/// Main Embrace system used to report crashes.
public final class EmbraceCrashReporter: NSObject, @unchecked Sendable {

    private let reporter: CrashReporter
    private let logger: InternalLogger?
    internal let queue: DispatchQueue = DispatchQueue(
        label: "com.embrace.crashreporter", qos: .utility, autoreleaseFrequency: .workItem)
    private let signalsBlockList: [CrashSignal]

    struct MutableData {
        let internalKeys: [String] = [CrashReporterInfoKey.sdkVersion, CrashReporterInfoKey.sessionId]
        var allowsInternalDataChange: Bool = false
    }
    private let data = EmbraceMutex(MutableData())

    // this is the path that contains `/Reports`.
    var basePath: String? {
        return reporter.basePath
    }

    /// Sets the current session identifier that will be included in a crash report.
    public var currentSessionId: String? {
        get {
            getCrashInfo(key: CrashReporterInfoKey.sessionId)
        }
        set {
            data.withLock { $0.allowsInternalDataChange = true }
            defer {
                data.withLock { $0.allowsInternalDataChange = false }
            }
            appendCrashInfo(key: CrashReporterInfoKey.sessionId, value: newValue)
        }
    }

    /// Adds the SDK version to the crash reports.
    private(set) var sdkVersion: String? {
        get {
            getCrashInfo(key: CrashReporterInfoKey.sdkVersion)
        }
        set {
            data.withLock { $0.allowsInternalDataChange = true }
            defer {
                data.withLock { $0.allowsInternalDataChange = false }
            }
            appendCrashInfo(key: CrashReporterInfoKey.sdkVersion, value: newValue)
        }
    }

    /// Use this to prevent MetricKit reports to be used along with this crash reporter
    public var disableMetricKitReports: Bool {
        reporter.disableMetricKitReports
    }

    /// Unused in this KSCrash implementation
    public var onNewReport: ((EmbraceCrashReport) -> Void)? {
        get {
            reporter.onNewReport
        }
        set {
            reporter.onNewReport = newValue
        }
    }

    public init(
        reporter: CrashReporter,
        logger: InternalLogger? = nil,
        signalsBlockList: [CrashSignal] = [.SIGTERM]
    ) {
        self.reporter = reporter
        self.logger = logger
        self.signalsBlockList = signalsBlockList
        super.init()
    }

    /// Used to determine if the last session ended cleanly or in a crash.
    public func getLastRunState() -> LastRunState {
        reporter.getLastRunState()
    }

    public func install(context: CrashReporterContext) {
        sdkVersion = context.sdkVersion
        do {
            try reporter.install(context: context)
        } catch {
            logger?.error("EmbraceCrashReporter install failed: \(error)")
        }
    }

    /// Fetches all saved `EmbraceCrashReport`.
    /// - Parameter completion: Completion handler to be called with the fetched `CrashReports`
    public func fetchUnsentCrashReports(completion: @escaping @Sendable ([EmbraceCrashReport]) -> Void) {
        queue.async { [self] in
            reporter.fetchUnsentCrashReports { [self] reports in

                var reportsToSend: [EmbraceCrashReport] = []

                for report in reports {
                    // Check if we drop crashes for a specific signal using the signalsBlockList
                    if let crashSignal = report.signal, shouldDropCrashReport(withSignal: crashSignal) {
                        // if we find a report we should drop, then we also delete it from KSCrash
                        deleteCrashReport(report)
                        continue
                    }
                    reportsToSend.append(report)
                }

                completion(reportsToSend)
            }
        }
    }

    /// Permanently deletes a crash report for the given identifier.
    /// - Parameter id: Identifier of the report to delete
    public func deleteCrashReport(_ report: EmbraceCrashReport) {
        reporter.deleteCrashReport(report)
    }

    /// Notifies if a crash report should be dropped by checking if the provided `CrashSignal` is in the `signalsBlockList`.
    func shouldDropCrashReport(withSignal signal: CrashSignal) -> Bool {
        signalsBlockList.contains(where: { $0 == signal })
    }

    public func appendCrashInfo(key: String, value: String?) {
        let allowed = data.withLock {
            if $0.internalKeys.contains(key) && !$0.allowsInternalDataChange {
                return false
            }
            return true
        }
        guard allowed else {
            return
        }
        reporter.appendCrashInfo(key: key, value: value)
    }

    public func getCrashInfo(key: String) -> String? {
        reporter.getCrashInfo(key: key)
    }
}
