//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import KSCrashRecording

/// Default `CrashReporter` used by the Embrace SDK.
/// Internally uses KSCrash to capture data from crashes.
@objc(EMBEmbraceCrashReporter)
public final class EmbraceCrashReporter: NSObject, CrashReporter {
    private static let providerIdentifier = "kscrash"

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

    @ThreadSafe
    var ksCrash: KSCrash?

    var logger: InternalLogger?
    private let queue: DispatchableQueue
    private let signalsBlockList: [CrashSignal]

    public private(set) var basePath: String?

    /// Sets the current session identifier that will be included in a crash report.
    public var currentSessionId: String? {
        didSet {
            updateKSCrashInfo()
        }
    }

    /// Adds the SDK version to the crash reports.
    private(set) var sdkVersion: String? {
        didSet {
            updateKSCrashInfo()
        }
    }

    private(set) var extraInfo: [String: String] = [:] {
        didSet {
            updateKSCrashInfo()
        }
    }

    /// Unused in this KSCrash implementation
    public var onNewReport: ((CrashReport) -> Void)?

    public init(queue: DispatchableQueue = .with(label: "com.embrace.crashreporter"),
                signalsBlockList: [CrashSignal] = [.SIGTERM]
    ) {
        self.queue = queue
        self.signalsBlockList = signalsBlockList
    }

    private func updateKSCrashInfo() {
        guard let ksCrash = ksCrash else {
            return
        }

        var crashInfo: [AnyHashable: Any] = ksCrash.userInfo ?? [:]

        self.extraInfo.forEach {
            crashInfo[$0.key] = $0.value
        }

        crashInfo[KSCrashKey.sdkVersion] = self.sdkVersion ?? NSNull()
        crashInfo[KSCrashKey.sessionId] = self.currentSessionId ?? NSNull()

        ksCrash.userInfo = crashInfo
    }

    /// Used to determine if the last session ended cleanly or in a crash.
    public func getLastRunState() -> LastRunState {
        guard let ksCrash = ksCrash else {
            return .unavailable
        }

        return ksCrash.crashedLastLaunch ? .crash : .cleanExit
    }

    public func install(context: CrashReporterContext, logger: InternalLogger) {
#if !os(watchOS)
        guard ksCrash == nil else {
            logger.debug("EmbraceCrashReporter already installed!")
            return
        }

        self.logger = logger
        sdkVersion = context.sdkVersion
        basePath = context.filePathProvider.directoryURL(for: "embrace_crash_reporter")?.path

        let bundleName = context.appId ?? "default"
        ksCrash = KSCrash.sharedInstance(withBasePath: basePath, andBundleName: bundleName)
        ksCrash?.reportsMemoryTerminations = false // this feature seems to have many issues, disabling it for now

        updateKSCrashInfo()
        ksCrash?.install()
#else
        logger.error("EmbraceCrashReporter is not supported in WatchOS!!!")
#endif
    }

    /// Fetches all saved `CrashReports`.
    /// - Parameter completion: Completion handler to be called with the fetched `CrashReports`
    public func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void) {
        guard ksCrash != nil else {
            completion([])
            return
        }

        queue.async { [weak self] in
            guard let self = self else {
                return
            }

            guard let reports = self.ksCrash?.reportIDs() else {
                completion([])
                return
            }

            // get all report ids
            var crashReports: [CrashReport] = []
            for reportId in reports {
                guard let id = reportId as? NSNumber else {
                    continue
                }

                // fetch report
                guard let report = self.ksCrash?.report(withID: id) as? [String: Any] else {
                    continue
                }

                // Check if we drop crashes for a specific signal using the signalsBlockList
                if let crashSignal = self.getCrashSignal(fromReport: report),
                   self.shouldDropCrashReport(withSignal: crashSignal) {
                    // if we find a report we should drop, then we also delete it from KSCrash
                    self.deleteCrashReport(id: id.intValue)
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

                if let userDict = report[KSCrashKey.user] as? [AnyHashable: Any] {
                    if let value = userDict[KSCrashKey.sessionId] as? String {
                        sessionId = SessionIdentifier(string: value)
                    }
                }

                if let reportDict = report[KSCrashKey.crashReport] as? [AnyHashable: Any],
                   let rawTimestamp = reportDict[KSCrashKey.timestamp] as? String {
                    timestamp = EmbraceCrashReporter.dateFormatter.date(from: rawTimestamp)
                }

                // add report
                let crashReport = CrashReport(
                    payload: payload,
                    provider: EmbraceCrashReporter.providerIdentifier,
                    internalId: id.intValue,
                    sessionId: sessionId?.toString,
                    timestamp: timestamp
                )

                crashReports.append(crashReport)
            }

            completion(crashReports)
        }
    }

    /// Extracts the `CrashSignal` from the KSCrash report
    ///
    /// By default, the signal object is under `crash.error.signal` in the KSCrash report. A signal object can have:
    /// `signal` (the numeric representation of the signal) and/or `name`.
    ///  This method uses those values to create a `CrashSignal`.
    ///
    /// - Parameter report: Dictionary representing a KSCrash report
    /// - Returns: The `CrashSignal` of the report. Could be `nil` if not found or is an invalid report.
    func getCrashSignal(fromReport report: [String: Any]) -> CrashSignal? {
        guard let crashPayload = report[KSCrashKey.crash] as? [String: Any],
              let errorPayload = crashPayload[KSCrashKey.error] as? [String: Any],
              let signalPayload = errorPayload[KSCrashKey.signal] as? [String: Any]
        else {
            return nil
        }

        if let signalName = signalPayload[KSCrashKey.signalName] as? String,
           let crashSignal = CrashSignal(rawValue: signalName) {
            return crashSignal
        }

        if let signalCode = signalPayload[KSCrashKey.signal] as? Int,
           let crashSignal = CrashSignal.from(code: signalCode) {
            return crashSignal
        }

        return nil
    }

    /// Notifies if a crash report should be dropped by checking if the provided `CrashSignal` is in the `signalsBlockList`.
    func shouldDropCrashReport(withSignal signal: CrashSignal) -> Bool {
        signalsBlockList.contains(where: { $0 == signal })
    }

    /// Permanently deletes a crash report for the given identifier.
    /// - Parameter id: Identifier of the report to delete
    public func deleteCrashReport(id: Int) {
        ksCrash?.deleteReport(withID: NSNumber(value: id))
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.formatterBehavior = .default
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

// MARK: - ExtendableCrashReporter related methods
extension EmbraceCrashReporter: ExtendableCrashReporter {
    public func appendCrashInfo(key: String, value: String) {
        extraInfo[key] = value
    }
}

// MARK: - CrashSignal definition
public extension EmbraceCrashReporter {
    enum CrashSignal: String {
        case SIGABRT
        case SIGBUS
        case SIGFPE
        case SIGILL
        case SIGPIPE
        case SIGSEGV
        case SIGSYS
        case SIGTRAP
        case SIGTERM

        static func from(code: Int) -> CrashSignal? {
            switch code {
            case 6: return SIGABRT
            case 10: return SIGBUS
            case 8: return SIGFPE
            case 4: return SIGILL
            case 13: return SIGPIPE
            case 11: return SIGSEGV
            case 12: return SIGSYS
            case 5: return SIGTRAP
            case 15: return SIGTERM
            default: return nil
            }
        }

        var name: String {
            self.rawValue
        }
    }
}
