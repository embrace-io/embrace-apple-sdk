//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Special `CrashReporter` implementation that captures crash data from Crashlytics reports.
public final class CrashlyticsReporter: CrashReporter {

    static let providerIdentifier = "crashlytics"

    class Options {
        let domain: String
        let path: String

        init(domain: String, path: String) {
            self.domain = domain
            self.path = path
        }
    }

    public convenience init() {
        self.init(
            options: Options(
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

    public var basePath: String? {
        nil
    }

    /// We let Crashlytics handle MetricKit
    public var disableMetricKitReports: Bool {
        true
    }

    /// Block called when there's a new report to upload
    public var onNewReport: ((EmbraceCrashReport) -> Void)?

    /// Always returns `.invalid`
    public func getLastRunState() -> LastRunState {
        return .unavailable
    }

    public func install(context: CrashReporterContext) throws {
        self.context = context
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
            let urlString = request.url?.absoluteString
        else {
            return
        }

        guard urlString.contains(options.domain) && urlString.contains(options.path) else {
            return
        }

        guard let body = request.httpBody else {
            return
        }

        let report = EmbraceCrashReport(
            payload: body.base64EncodedString(),
            provider: CrashlyticsReporter.providerIdentifier
        )
        onNewReport?(report)
    }

    /// Unused
    public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {
        completion([])
    }

    /// Unused
    public func deleteCrashReport(_ report: EmbraceCrashReport) {
    }

    public func appendCrashInfo(key: String, value: String?) {
        if let value {
            wrapper.setCustomValue(key: key, value: value)
        }
    }

    public func getCrashInfo(key: String) -> String? {
        wrapper.getCustomValue(key: key)
    }
}
