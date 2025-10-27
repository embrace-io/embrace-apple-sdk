//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

#if canImport(KSCrashRecording)
    import KSCrashRecording
#elseif canImport(KSCrash)
    import KSCrash
#endif

@objc(KSCrashReporter)
public final class KSCrashReporter: NSObject, CrashReporter {

    // KSCrash uses C callbacks. We can't capture Swift in them.
    // The workaround is to hold onto a private shared instance.
    private static weak var shared: KSCrashReporter?

    private struct KSCrashKey {
        static let user = "user"
        static let crashReport = "report"
        static let timestamp = "timestamp"
        static let crash = "crash"
        static let error = "error"
        static let signal = "signal"
        static let signalName = "signal"
    }

    internal struct KSCrashWatchdogEventKey {
        static let watchdgodEvent = "watchdog_event"
    }

    private let reporter: KSCrash = KSCrash.shared

    struct WatchdogEventData {
        var reportID: Int64? = nil
        var inEvent: Bool = false
        var event: WatchdogEvent? = nil
    }
    private var watchdogData: EmbraceMutex<WatchdogEventData> = EmbraceMutex(WatchdogEventData())
    private var hangObservers: [NSObjectProtocol] = []

    public override init() {
        reporter.userInfo = [:]
        super.init()
        KSCrashReporter.shared = self
    }

    deinit {
        unregisterForHangs()
    }

    // this is the path that contains `/Reports`.
    public var basePath: String? {
        return reporter.value(forKeyPath: "configuration.installPath") as? String
    }

    /// Use this to prevent MetricKit reports to be used along with this crash reporter
    public var disableMetricKitReports: Bool {
        false
    }

    /// Unused in this KSCrash implementation
    public var onNewReport: ((EmbraceCrashReport) -> Void)?

    /// Used to determine if the last session ended cleanly or in a crash.
    public func getLastRunState() -> LastRunState {
        return reporter.crashedLastLaunch ? .crash : .cleanExit
    }

    public func install(context: CrashReporterContext) throws {
        #if !os(watchOS)
            let config = KSCrashConfiguration()
            config.enableSigTermMonitoring = false
            config.enableSwapCxaThrow = false
            config.installPath = context.filePathProvider.directoryURL(for: "embrace_crash_reporter")?.path
            config.reportStoreConfiguration.appName = context.appId ?? "default"
            config.didWriteReportCallback = { _, reportID in
                KSCrashReporter.shared?.watchdogData.withLock {
                    guard $0.inEvent else { return }
                    $0.reportID = reportID
                }
            }
            try reporter.install(with: config)
            registerForHangs()
        #endif
    }

    /// Fetches all saved `EmbraceCrashReport`.
    /// - Parameter completion: Completion handler to be called with the fetched `CrashReports`
    public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {

        let results: [EmbraceCrashReport]
        defer {
            completion(results)
        }

        guard let store = reporter.reportStore else {
            results = []
            return
        }

        // get all report ids
        var crashReports: [EmbraceCrashReport] = []
        for reportId in store.reportIDs {
            guard let id = reportId as? Int64 else {
                continue
            }

            // fetch report
            guard var report = store.report(for: id)?.value else {
                continue
            }

            // check the _name_, if it's a `watchdog_event`, we need to modify the `crashed_thread`.
            if report.isWatchdogEvent() {
                report.changeCrashedThread(to: 0)
            }

            // serialize json
            var payload: String?
            do {
                let data = try JSONSerialization.data(withJSONObject: report)
                if let json = String(data: data, encoding: String.Encoding.utf8) {
                    payload = json
                }
            } catch {
            }

            guard let payload = payload else {
                continue
            }

            // get custom data from report
            var sessionId: SessionIdentifier?
            var timestamp: Date?
            let signal: CrashSignal? = getCrashSignal(fromReport: report)

            if let userDict = report[KSCrashKey.user] as? [AnyHashable: Any] {
                if let value = userDict[CrashReporterInfoKey.sessionId] as? String {
                    sessionId = SessionIdentifier(string: value)
                }
            }

            if let reportDict = report[KSCrashKey.crashReport] as? [AnyHashable: Any],
                let rawTimestamp = reportDict[KSCrashKey.timestamp] as? String
            {
                timestamp = Self.dateFormatter.date(from: rawTimestamp)
            }

            // add report
            let crashReport = EmbraceCrashReport(
                payload: payload,
                provider: "kscrash",  // from LogSemantics+Crash.swift
                internalId: Int(id),
                sessionId: sessionId?.toString,
                timestamp: timestamp,
                signal: signal
            )

            crashReports.append(crashReport)
        }

        results = crashReports
    }

    /// Extracts the `CrashSignal` from the KSCrash report
    func getCrashSignal(fromReport report: [String: Any]) -> CrashSignal? {
        guard let crashPayload = report[KSCrashKey.crash] as? [String: Any],
            let errorPayload = crashPayload[KSCrashKey.error] as? [String: Any],
            let signalPayload = errorPayload[KSCrashKey.signal] as? [String: Any]
        else {
            return nil
        }

        if let signalName = signalPayload[KSCrashKey.signalName] as? String {
            return CrashSignal.from(string: signalName)
        }

        if let signalCode = signalPayload[KSCrashKey.signal] as? Int {
            return CrashSignal(rawValue: signalCode)
        }

        return nil
    }

    /// Permanently deletes a crash report for the given identifier.
    /// - Parameter id: Identifier of the report to delete
    public func deleteCrashReport(_ report: EmbraceCrashReport) {
        if let id = report.internalId {
            reporter.reportStore?.deleteReport(with: Int64(id))
        }
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.formatterBehavior = .default
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    public func appendCrashInfo(key: String, value: String?) {
        reporter.userInfo?[key] = value
    }

    public func getCrashInfo(key: String) -> String? {
        reporter.userInfo?[key] as? String
    }

}

// MARK: - Watchdog (hang) integration

/// When a hang starts, we write a synthetic crash report to disk. When the hang
/// recovers, we delete that report. If the OS terminates the app during the hang
/// (0x8badf00d for blocking the main thread), the synthetic report remains on disk
/// and is picked up on next launch as a regular crash report. This routes watchdog
/// terminations through the same crash pipeline without crashing the process.
extension KSCrashReporter {

    /// Subscribes to `.hangEventStarted` and `.hangEventEnded` and forwards them to the
    /// corresponding handlers. Observers are stored in `hangObservers`.
    private func registerForHangs() {
        let obs1 = NotificationCenter.default.addObserver(forName: .hangEventStarted, object: nil, queue: nil) { [weak self] notification in
            if let event = notification.object as? WatchdogEvent {
                self?.watchdogEventStarted(event)
            }
        }
        hangObservers.append(obs1)

        let obs2 = NotificationCenter.default.addObserver(forName: .hangEventEnded, object: nil, queue: nil) { [weak self] notification in
            if let event = notification.object as? WatchdogEvent {
                self?.watchdogEventEnded(event)
            }
        }
        hangObservers.append(obs2)
    }

    /// Removes previously registered hang observers and clears `hangObservers`.
    private func unregisterForHangs() {
        let observers = hangObservers
        hangObservers.removeAll()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Hang began: delete any prior synthetic report and write a new user-exception
    /// report to disk with the hang duration in the reason.
    public func watchdogEventStarted(_ event: WatchdogEvent) {

        deleteWatchdogReport(nextEvent: event)

        reporter.reportUserException(
            KSCrashWatchdogEventKey.watchdgodEvent,
            reason: "0x8badf00d, main thread blocked for \(event.duration.uptime.secondsValue) seconds.",
            language: nil,
            lineOfCode: nil,
            stackTrace: nil,
            logAllThreads: true,
            terminateProgram: false
        )
    }

    /// Hang ended: delete the synthetic report, if present.
    public func watchdogEventEnded(_ event: WatchdogEvent) {
        deleteWatchdogReport(nextEvent: nil)
    }

    /// Deletes the most recent synthetic watchdog report (if any) and clears
    /// in-flight state under `watchdogData`.
    private func deleteWatchdogReport(nextEvent: WatchdogEvent?) {

        let reportId = watchdogData.withLock {
            let reportId = $0.reportID
            $0.event = nextEvent
            $0.inEvent = false
            $0.reportID = nil
            return reportId
        }
        if let wid = reportId {
            reporter.reportStore?.deleteReport(with: wid)
        }
    }
}

// KSCrash report format support
extension Dictionary where Key == String, Value == Any {

    /// Check if this data shows it being a watchdog event report from KSCrash.
    fileprivate func isWatchdogEvent() -> Bool {
        if let crashData = self["crash"] as? [String: Any],
            let errorData = crashData["error"] as? [String: Any],
            let userReportedData = errorData["user_reported"] as? [String: Any],
            let name = userReportedData["name"] as? String
        {
            return name == KSCrashReporter.KSCrashWatchdogEventKey.watchdgodEvent
        }
        return false
    }

    /// Updates the crashed thread to a specific thread index.
    mutating fileprivate func changeCrashedThread(to: Int) {
        guard var crashData = self["crash"] as? [String: Any],
            var threadsData = crashData["threads"] as? [[String: Any]]
        else {
            return
        }

        for i in 0..<threadsData.count {
            if let threadIndex = threadsData[i]["index"] as? Int {
                let isTarget = threadIndex == to
                threadsData[i]["crashed"] = isTarget
                threadsData[i]["current_thread"] = isTarget
            }
        }

        crashData["threads"] = threadsData
        self["crash"] = crashData
    }
}
