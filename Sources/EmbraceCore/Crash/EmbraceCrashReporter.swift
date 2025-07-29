//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Default `CrashReporter` used by the Embrace SDK.
/// Internally uses KSCrash to capture data from crashes.
public final class EmbraceCrashReporter: NSObject {

    private let reporter: CrashReporter
    private let logger: InternalLogger?
    internal let queue: DispatchQueue = DispatchQueue(
        label: "com.embrace.crashreporter", qos: .utility, autoreleaseFrequency: .workItem)
    private let signalsBlockList: [CrashSignal]

    // this is the path that contains `/Reports`.
    var basePath: String? {
        return reporter.basePath
    }

    /// Sets the current session identifier that will be included in a crash report.
    public var currentSessionId: String? {
        set {
            reporter.currentSessionId = newValue
        }
        get {
            reporter.currentSessionId
        }
    }

    /// Adds the SDK version to the crash reports.
    private(set) var sdkVersion: String? {
        set {
            reporter.sdkVersion = newValue
        }
        get {
            reporter.sdkVersion
        }
    }

    /// Use this to prevent MetricKit reports to be used along with this crash reporter
    public var disableMetricKitReports: Bool {
        reporter.disableMetricKitReports
    }

    /// Unused in this KSCrash implementation
    public var onNewReport: ((EmbraceCrashReport) -> Void)? {
        set {
            reporter.onNewReport = newValue
        }
        get {
            reporter.onNewReport
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
    public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {
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

    public func appendCrashInfo(key: String, value: String) {
        reporter.appendCrashInfo(key: key, value: value)
    }

    public func getCrashInfo(key: String) -> String? {
        reporter.getCrashInfo(key: key)
    }
}
