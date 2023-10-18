//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import KSCrash_Recording

/// Class used to interact with KSCrash
@objc public class EmbraceCrashReporter: NSObject, InstalledCollector, CrashReporter {

    enum UserInfoKey {
        static let sessionId = "emb-sid"
        static let sdkVersion = "emb-sdk"
        static let appVersion = "emb-app"
    }

    var ksCrash: KSCrash?
    private var userInfo: [String: String] = [:]
    private var queue: DispatchQueue = DispatchQueue(label: "com.embrace.crashreporter")

    private var appId: String?
    private var basePath: String?

    public func isAvailable() -> Bool {
        return true
    }

    /// Used to setup the path where crashes are saved.
    /// - Parameters:
    ///   - appId: The current appId used by Embrace
    ///   - path: The path where crashes should be stored
    public func configure(appId: String?, path: String?) {
        self.appId = appId
        self.basePath = path
    }

    /// Sets the current session identifier that will be included in a crash report.
    public var currentSessionId: SessionId? {
        get {
            return userInfo[UserInfoKey.sessionId]
        }
        set {
            setUserInfoValue(newValue, key: UserInfoKey.sessionId)
        }
    }

    /// Adds the SDK version to the crash reports.
    public var sdkVersion: String? {
        get {
            return userInfo[UserInfoKey.sdkVersion]
        }
        set {
            setUserInfoValue(newValue, key: UserInfoKey.sdkVersion)
        }
    }

    /// Adds the app version to the crash reports.
    public var appVersion: String? {
        get {
            return userInfo[UserInfoKey.appVersion]
        }
        set {
            setUserInfoValue(newValue, key: UserInfoKey.appVersion)
        }
    }

    private func setUserInfoValue(_ value: String?, key: String) {
        // TODO: Concurrency handling
        userInfo[key] = value
        ksCrash?.userInfo = userInfo
    }

    /// Used to determine if the last session ended cleanly or in a crash.
    public func getLastRunState() -> LastRunState {
        // TODO: Concurrency handling
        guard let ksCrash = ksCrash else {
            return .invalid
        }

        return ksCrash.crashedLastLaunch ? .crash : .cleanExit
    }

    public func install() {
        guard ksCrash == nil else {
            print("EmbraceCrashReporter already started!")
            return
        }

        guard let basePath = basePath,
              let appId = appId else {
            print("EmbraceCrashReported failed to initialize!")
            return
        }

        ksCrash = KSCrash.sharedInstance(withBasePath: basePath, andBundleName: appId)
        ksCrash?.userInfo = userInfo
    }

    public func start() {
        ksCrash?.install()
    }

    /// Fetches all saved `CrashReports`.
    /// - Parameter completion: Completion handler to be called with the fetched `CrashReports`
    public func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void) {
        // TODO: Concurrency handling
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
                guard let report = self?.ksCrash?.report(withID: id),
                      let data = self?.getEncodedReport(report) else {
                        continue
                }

                // get custom data from report
                var sessionId: SessionId?
                var sdkVersion: String?
                var appVersion: String?
                var timestamp: Date?

                if let userDict = report["user"] as? [AnyHashable: Any] {
                    sessionId = userDict[UserInfoKey.sessionId] as? SessionId
                    sdkVersion = userDict[UserInfoKey.sdkVersion] as? String
                    appVersion = userDict[UserInfoKey.appVersion] as? String
                }

                if let reportDict = report["report"] as? [AnyHashable: Any],
                   let rawTimestamp = reportDict["timestamp"] as? String {
                    timestamp = EmbraceCrashReporter.dateFormatter.date(from: rawTimestamp)
                }

                // add report
                let crashReport = CrashReport(
                    ksCrashId: id.intValue,
                    sessionId: sessionId,
                    sdkVersion: sdkVersion,
                    appVersion: appVersion,
                    timestamp: timestamp,
                    data: data
                )

                crashReports.append(crashReport)
            }

            completion(crashReports)
        }
    }

    private func getEncodedReport(_ report: [AnyHashable: Any]) -> Data? {
        do {
            return try KSJSONCodec.encode(report, options: KSJSONEncodeOptionSorted)
        } catch {
            print("Error enconding crash: " + error.localizedDescription)
            return nil
        }
    }

    /// Permanently deletes a crash report for the given identifier.
    /// - Parameter id: Identifier of the report to delete
    public func deleteCrashReport(id: Int) {
        // TODO: Concurrency handling
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

    // MARK: - Unused
    public func shutdown() {

    }

    public func stop() {

    }
}
