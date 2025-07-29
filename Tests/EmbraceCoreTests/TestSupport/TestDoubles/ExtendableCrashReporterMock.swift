//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

class ExtendableCrashReporterMock: CrashReporter {
    var sdkVersion: String?
    var basePath: String?

    var didCallAppendCrashInfo: Bool = false
    func appendCrashInfo(key: String, value: String) {
        didCallAppendCrashInfo = true
    }

    var didCallGetCrashInfo: Bool = false
    func getCrashInfo(key: String) -> String? {
        didCallGetCrashInfo = true
        return nil
    }

    var currentSessionId: String?
    func install(context: EmbraceCommonInternal.CrashReporterContext) throws {}
    func getLastRunState() -> EmbraceCommonInternal.LastRunState {
        .unavailable
    }
    func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {}
    func deleteCrashReport(_ report: EmbraceCrashReport) {}
    var onNewReport: ((EmbraceCrashReport) -> Void)?
    var disableMetricKitReports: Bool = false
}
