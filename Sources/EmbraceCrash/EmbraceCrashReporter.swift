//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import KSCrash_Recording

/// Class used to interact with KSCrash
@objc public final class EmbraceCrashReporter: NSObject, CrashReporter {

    enum UserInfoKey {
        static let sessionId = "emb-sid"
        static let sdkVersion = "emb-sdk"
    }

    @ThreadSafe
    var ksCrash: KSCrash?

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

    private func updateKSCrashInfo() {
        guard let ksCrash = ksCrash else {
            return
        }

        ksCrash.userInfo = [
            UserInfoKey.sdkVersion: sdkVersion ?? NSNull(),
            UserInfoKey.sessionId: currentSessionId ?? NSNull()
        ]
    }

    /// Used to determine if the last session ended cleanly or in a crash.
    public func getLastRunState() -> LastRunState {
        guard let ksCrash = ksCrash else {
            return .invalid
        }

        return ksCrash.crashedLastLaunch ? .crash : .cleanExit
    }

    public func install(context: EmbraceCommon.CrashReporterContext) {
        guard ksCrash == nil else {
            ConsoleLog.debug("EmbraceCrashReporter already installed!")
            return
        }

        sdkVersion = context.sdkVersion
        appId = context.appId
        basePath = context.filePathProvider.directoryURL(for: "embrace_crash_reporter")?.path

        ksCrash = KSCrash.sharedInstance(withBasePath: basePath, andBundleName: appId)
        updateKSCrashInfo()
    }

    public func start() {
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
                    ksCrashId: id.intValue,
                    sessionId: sessionId?.toString,
                    timestamp: timestamp,
                    dictionary: report
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
