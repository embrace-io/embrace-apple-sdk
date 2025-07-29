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

@objc(KSCrashReporter)
public final class KSCrashReporter: NSObject, CrashReporter {

    struct KSCrashKey {
        static let user = "user"
        static let crashReport = "report"
        static let timestamp = "timestamp"
        static let crash = "crash"
        static let error = "error"
        static let signal = "signal"
        static let signalName = "signal"
        static let sessionId = "emb-sid"
        static let sdkVersion = "emb-sdk"
    }

    private let reporter: KSCrash = KSCrash.shared
    private var logger: InternalLogger?

    // this is the path that contains `/Reports`.
    public var basePath: String? {
        return reporter.value(forKeyPath: "configuration.installPath") as? String
    }

    /// Sets the current session identifier that will be included in a crash report.
    public var currentSessionId: String? {
        set {
            reporter.userInfo?[KSCrashKey.sessionId] = newValue ?? NSNull()
        }
        get {
            reporter.userInfo?[KSCrashKey.sessionId] as? String
        }
    }

    /// Adds the SDK version to the crash reports.
    public var sdkVersion: String? {
        set {
            reporter.userInfo?[KSCrashKey.sdkVersion] = newValue ?? NSNull()
        }
        get {
            reporter.userInfo?[KSCrashKey.sdkVersion] as? String
        }
    }

    /// Use this to prevent MetricKit reports to be used along with this crash reporter
    public var disableMetricKitReports: Bool {
        get { false }
        set {}
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
            guard let report = store.report(for: id)?.value else {
                continue
            }

            // serialize json
            var payload: String?
            do {
                let data = try JSONSerialization.data(withJSONObject: report)
                if let json = String(data: data, encoding: String.Encoding.utf8) {
                    payload = json
                } else {
                    self.logger?.warning("Error serializing raw crash report \(reportId)!")
                }
            } catch {
                self.logger?.warning("Error serializing raw crash report \(reportId)!")
            }

            guard let payload = payload else {
                continue
            }

            // get custom data from report
            var sessionId: SessionIdentifier?
            var timestamp: Date?
            let signal: CrashSignal? = getCrashSignal(fromReport: report)

            if let userDict = report[KSCrashKey.user] as? [AnyHashable: Any] {
                if let value = userDict[KSCrashKey.sessionId] as? String {
                    sessionId = SessionIdentifier(string: value)
                }
            }

            if let reportDict = report[KSCrashKey.crashReport] as? [AnyHashable: Any],
                let rawTimestamp = reportDict[KSCrashKey.timestamp] as? String {
                timestamp = Self.dateFormatter.date(from: rawTimestamp)
            }

            // add report
            let crashReport = EmbraceCrashReport(
                payload: payload,
                provider: LogSemantics.Crash.ksCrashProvider,
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

    public func appendCrashInfo(key: String, value: String) {
        reporter.userInfo?[key] = value
    }

    public func getCrashInfo(key: String) -> String? {
        reporter.userInfo?[key] as? String
    }
}
