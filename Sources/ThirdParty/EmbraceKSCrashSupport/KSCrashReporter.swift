//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

#if canImport(KSCrashRecording)
    import KSCrashRecording
#elseif canImport(KSCrash)
    import KSCrash
#endif

package final class KSCrashReporter: CrashReporter {

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

    private static let monitors: MonitorType = [
        .machException,
        .signal,
        .cppException,
        .nsException,
        .userReported,
        .termination
    ]

    private let reporter: KSCrash = KSCrash.shared

    struct WatchdogEventData {
        var reportID: Int64? = nil
        var inEvent: Bool = false
        var event: WatchdogEvent? = nil
    }
    private var watchdogData: EmbraceMutex<WatchdogEventData> = EmbraceMutex(WatchdogEventData())
    private var hangObservers: [NSObjectProtocol] = []

    public init() {
        reporter.userInfo = [:]
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
        return reporter.previousTerminationReason == .crash ? .crash : .cleanExit
    }

    public func install(context: CrashReporterContext) throws {
        let config = KSCrashConfiguration()
        config.monitors = Self.monitors
        config.enableSwapCxaThrow = false
        config.installPath = context.filePathProvider.directoryURL(for: "embrace_crash_reporter")?.path
        config.reportStoreConfiguration.appName = context.appId ?? "default"
        config.didWriteReportCallback = { _, reportID in
            KSCrashReporter.shared?.watchdogData.withLock {
                guard $0.inEvent else { return }
                $0.reportID = reportID
            }
        }
        // `reporter.install` reaches `ksbic_init`, which rewrites KSCrash's unsynchronized
        // `g_all_image_infos` global. Serialize against background log symbolication, which hits the
        // same global concurrently during startup. See `KSCrashGlobalsLock`.
        try KSCrashGlobalsLock.withLock {
            try reporter.install(with: config)
        }
        registerForHangs()
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

            // Drop all reports except OOMs.
            if report.isInjectedTerminationReport(), !report.isUserPerceptibleMemoryTermination() {
                store.deleteReport(with: id)
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
            var sessionId: EmbraceIdentifier?
            var processId: EmbraceIdentifier?
            var timestamp: Date?
            let signal: CrashSignal? = getCrashSignal(fromReport: report)

            if let userDict = report[KSCrashKey.user] as? [AnyHashable: Any] {
                if let value = userDict[CrashReporterInfoKey.sessionId] as? String {
                    sessionId = EmbraceIdentifier(stringValue: value)
                }

                // Absent in reports written before the SDK started recording it.
                if let value = userDict[CrashReporterInfoKey.processId] as? String {
                    processId = EmbraceIdentifier(stringValue: value)
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
                provider: LogSemantics.Crash.ksCrashProvider,
                internalId: EMBInt(id),
                sessionId: sessionId?.stringValue,
                processId: processId?.stringValue,
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
            reason: "0x8badf00d, main thread blocked for \(String(format: "%.3f", event.duration)) seconds.",
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

    private enum TerminationKey {
        static let monitorId = "Termination"
        static let memoryLimit = "memory_limit"
        static let memoryPressure = "memory_pressure"
    }

    /// Check if this report was injected retroactively by KSCrash's `termination` monitor
    /// rather than written by a crash handler during the previous run.
    ///
    /// These reports are hand-built by KSCrash and contain only a `report` and a `crash`
    /// section, so they carry no `user` section and therefore no session id.
    fileprivate func isInjectedTerminationReport() -> Bool {
        guard let reportData = self["report"] as? [String: Any],
            let monitorId = reportData["monitor_id"] as? String,
            monitorId == TerminationKey.monitorId
        else {
            return false
        }

        return true
    }

    /// Check if an injected termination report describes an out-of-memory kill that the user
    /// could have perceived, which is the only termination KSCrash 2.5.1 reported.
    ///
    /// `user_perceptible` is stitched in from the previous run's `Lifecycle` sidecar when the
    /// report is read, and mirrors the foreground check 2.5.1 applied before promoting its OOM
    /// breadcrumb. Its absence means we can't establish the app was in the foreground, so we
    /// treat that as not perceptible.
    fileprivate func isUserPerceptibleMemoryTermination() -> Bool {
        guard let crashData = self["crash"] as? [String: Any],
            let errorData = crashData["error"] as? [String: Any],
            let reason = errorData["termination_reason"] as? String,
            reason == TerminationKey.memoryLimit || reason == TerminationKey.memoryPressure
        else {
            return false
        }

        guard let systemData = self["system"] as? [String: Any],
            let appStats = systemData["application_stats"] as? [String: Any],
            let userPerceptible = appStats["user_perceptible"] as? Bool
        else {
            return false
        }

        return userPerceptible
    }

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
