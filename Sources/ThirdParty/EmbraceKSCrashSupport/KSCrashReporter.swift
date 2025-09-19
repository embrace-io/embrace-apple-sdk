//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceTerminations
#endif

#if canImport(KSCrashRecording)
    import KSCrashRecording
#elseif canImport(KSCrash)
    import KSCrash
#endif

@objc(KSCrashReporter)
public final class KSCrashReporter: NSObject, CrashReporter {

    private struct KSCrashKey {
        static let user = "user"
        static let crashReport = "report"
        static let timestamp = "timestamp"
        static let crash = "crash"
        static let error = "error"
        static let signal = "signal"
        static let signalName = "signal"
    }

    private var crashContext: CrashReporterContext? = nil
    private var lastSession: String?
    private var threadcrumb = EmbraceThreadcrumb()
    private let reporter: KSCrash = KSCrash.shared

    public override init() {
        super.init()
        self.reporter.userInfo = [:]
        self.lastSession = try? String(contentsOf: Self.lastSessionURL, encoding: .utf8)
    }

    // this is the path that contains `/Reports`.
    public var basePath: String? {
        return reporter.value(forKeyPath: "configuration.installPath") as? String
    }

    /// Use this to prevent MetricKit reports to be used along with this crash reporter
    public let disableMetricKitReports: Bool = false

    /// Unused in this KSCrash implementation
    public var onNewReport: ((EmbraceCrashReport) -> Void)?

    /// Used to determine if the last session ended cleanly or in a crash.
    public func getLastRunState() -> LastRunState {
        return reporter.crashedLastLaunch ? .crash : .cleanExit
    }

    public func install(context: CrashReporterContext) throws {
        crashContext = context
        #if !os(watchOS)
            let config = KSCrashConfiguration()
            config.enableSigTermMonitoring = true
            config.enableSwapCxaThrow = false
            config.installPath = context.filePathProvider.directoryURL(for: "embrace_crash_reporter")?.path
            config.reportStoreConfiguration.appName = context.appId ?? "default"
            config.monitors = [.cppException, .machException, .nsException, .signal, .userReported, .system, .applicationState]
            config.willWriteReportCallback = EMBTerminationStorageWillWriteCrashEvent

            do {
                try reporter.install(with: config)
            } catch {
                context.logger.error("KSCrash install failed \(error)")
                throw error
            }
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
                internalId: "\(id)",
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
        if let sid = report.internalId, let id = Int64(sid) {
            reporter.reportStore?.deleteReport(with: id)
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
        if key == CrashReporterInfoKey.sessionId {
            if let value {

                // log it
                crashContext?.logger.info("sid: \(value)")
                let stack = threadcrumb.log(value).map { UInt64(truncating: $0) } ?? []
                _writeSymbols(
                    stack,
                    sessionId: value,
                    processId: ProcessIdentifier.current.value,
                    sdk: crashContext?.sdkVersion
                )
                try? value.write(to: Self.lastSessionURL, atomically: false, encoding: .utf8)
            }
        } else if key == CrashReporterInfoKey.sdkVersion {
        }
    }

    public func getCrashInfo(key: String) -> String? {
        reporter.userInfo?[key] as? String
    }

}

extension KSCrashReporter: TerminationReporter {

    public func deleteTerminationData(_ metadata: TerminationMetadata) async {
        if !EMBTerminationStorageRemoveForIdentifier(metadata.processId) {
            crashContext?.logger.error("Error deleting temrination data for identifier: \(metadata.processId)")
        }
    }

    public func fetchUnsentTerminationAttributes() async -> [TerminationMetadata] {
        let identifiers: [String] = EMBTerminationStorageGetIdentifiers()
        return identifiers.compactMap { id in

            // don't send the current one
            if id == ProcessIdentifier.current.value {
                return nil
            }

            var storage = TerminationStorage()
            let ok = withUnsafeMutablePointer(to: &storage) { ptr in
                EMBTerminationStorageForIdentifier(id, ptr)
            }
            if ok {
                return TerminationMetadata(
                    processId: storage.processIdentifier,
                    timestamp: storage.lastKnownDate,
                    metadata: storage.toDictionary()
                )
            }
            return nil
        }
    }

    private func _writeSymbols(_ symbols: [UInt64], sessionId: String, processId: String, sdk: String?) {

        crashContext?.logger.info("_writeSymbols")

        guard symbols.count == 32 else {
            crashContext?.logger.error("received \(symbols.count) symbols, expected 32")
            return
        }

        // we're looking for a thread with 39 frames.
        // `__impact_threadcrumb_end__`
        // => ... 32 frames of `__impact__<N>__` for the GUID of the session it was part of (no hyphens).
        // `__impact_threadcrumb_start__`
        // `_pthread_start`
        // `thread_start`
        var combinedHash: UInt64 = 0
        for i in (0..<32) {
            let addr: UInt64 = symbols[i]
            crashContext?.logger.info("\(i) => frame addr: \(addr)")
            let shift = UInt64((i % 63) + 1)  // use zero-based index
            let rotated = (addr << shift) | (addr >> (64 - shift))
            combinedHash ^= rotated
        }
        let filename = String(format: "%016llx.stacksym", combinedHash)
        let url = Self.symbolDirectoryURL.appendingPathComponent(filename)

        let output = [sessionId, processId, sdk].compactMap { $0 }.joined(separator: "\n")
        try? output.write(to: url, atomically: false, encoding: .utf8)
    }

}

extension KSCrashReporter {

    static private var lastSessionURL: URL {
        try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appendingPathComponent("last_session")
    }

    static private var symbolDirectoryURL: URL! {
        let url = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appendingPathComponent("ThreadcrumbSymbols")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
