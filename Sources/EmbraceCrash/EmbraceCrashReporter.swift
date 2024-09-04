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

    static let providerIdentifier = "kscrash"

    enum UserInfoKey {
        static let sessionId = "emb-sid"
        static let sdkVersion = "emb-sdk"
    }

    @ThreadSafe
    var ksCrash: KSCrash?

    var logger: InternalLogger?
    private var queue: DispatchQueue = DispatchQueue(label: "com.embrace.crashreporter")

    private var appId: String?
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

    private func updateKSCrashInfo() {
        guard let ksCrash = ksCrash else {
            return
        }

        var crashInfo: [AnyHashable: Any] = [:]

        if ksCrash.userInfo != nil {
            crashInfo = ksCrash.userInfo
        }

        crashInfo[UserInfoKey.sdkVersion] = self.sdkVersion ?? NSNull()
        crashInfo[UserInfoKey.sessionId] = self.currentSessionId ?? NSNull()

        self.extraInfo.forEach {
            crashInfo[$0.key] = $0.value
        }

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
        guard ksCrash == nil else {
            logger.debug("EmbraceCrashReporter already installed!")
            return
        }

        self.logger = logger
        sdkVersion = context.sdkVersion
        appId = context.appId
        basePath = context.filePathProvider.directoryURL(for: "embrace_crash_reporter")?.path

        ksCrash = KSCrash.sharedInstance(withBasePath: basePath, andBundleName: appId)
        updateKSCrashInfo()
        ksCrash?.install()
    }

    /// Fetches all saved `CrashReports`.
    /// - Parameter completion: Completion handler to be called with the fetched `CrashReports`
    public func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void) {
        guard ksCrash != nil else {
            completion([])
            return
        }

        queue.async { [weak self] in
            guard let reports = self?.ksCrash?.reportIDs() else {
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
                guard let report = self?.ksCrash?.report(withID: id) as? [String: Any] else {
                    continue
                }

                // serialize json
                var payload: String?
                do {
                    let data = try JSONSerialization.data(withJSONObject: report)
                    if let json = String(data: data, encoding: String.Encoding.utf8) {
                        payload = json
                    } else {
                        self?.logger?.warning("Error serializing raw crash report \(reportId)!")
                    }
                } catch {
                    self?.logger?.warning("Error serializing raw crash report \(reportId)!")
                }

                guard let payload = payload else {
                    continue
                }

                // get custom data from report
                var sessionId: SessionIdentifier?
                var timestamp: Date?

                if let userDict = report["user"] as? [AnyHashable: Any] {
                    if let value = userDict[UserInfoKey.sessionId] as? String {
                        sessionId = SessionIdentifier(string: value)
                    }
                }

                if let reportDict = report["report"] as? [AnyHashable: Any],
                   let rawTimestamp = reportDict["timestamp"] as? String {
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

extension EmbraceCrashReporter: ExtendableCrashReporter {
    public func appendCrashInfo(key: String, value: String) {
        extraInfo[key] = value
    }
}
