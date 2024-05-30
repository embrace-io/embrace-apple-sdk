//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

/// Class used to capture Crashlytics reports
@objc public final class CrashlyticsReporter: NSObject, CrashReporter {

    static let providerIdentifier = "crashlytics"

    class Options {
        let domain: String
        let path: String

        init(domain: String, path: String) {
            self.domain = domain
            self.path = path
        }
    }

    @objc public convenience override init() {
        self.init(options: Options(
            domain: "crashlyticsreports-pa.googleapis.com",
            path: "batchlog"
        ))
    }

    init(options: CrashlyticsReporter.Options) {
        self.options = options
    }

    let options: CrashlyticsReporter.Options
    var context: CrashReporterContext?

    /// Object used to interact with Firebase
    let wrapper: CrashlyticsWrapper = CrashlyticsWrapper()

    /// Sets the current session identifier that will be included in a crash report.
    public var currentSessionId: String? {
        didSet {
            wrapper.currentSessionId = currentSessionId
        }
    }

    /// Block called when there's a new report to upload
    public var onNewReport: ((CrashReport) -> Void)?

    /// Always returns `.invalid`
    public func getLastRunState() -> LastRunState {
        return .invalid
    }

    public func install(context: CrashReporterContext) {
        self.context = context
        wrapper.sdkVersion = context.sdkVersion

        context.notificationCenter.addObserver(
            self,
            selector: #selector(onNetworkRequestCaptured),
            name: Notification.Name("networkRequestCaptured"),
            object: nil
        )
    }

    deinit {
        context?.notificationCenter.removeObserver(self)
    }

    @objc func onNetworkRequestCaptured(notification: Notification) {
        guard let task = notification.object as? URLSessionTask else {
            return
        }

        guard let request = task.originalRequest,
              let urlString = request.url?.absoluteString else {
            return
        }

        guard urlString.contains(options.domain) && urlString.contains(options.path) else {
            return
        }

        guard let body = request.httpBody else {
            return
        }

        let report = CrashReport(
            payload: body.base64EncodedString(),
            provider: CrashlyticsReporter.providerIdentifier
        )
        onNewReport?(report)
    }

    /// Unused
    public func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void) {
        completion([])
    }

    /// Unused
    public func deleteCrashReport(id: Int) {

    }
}
