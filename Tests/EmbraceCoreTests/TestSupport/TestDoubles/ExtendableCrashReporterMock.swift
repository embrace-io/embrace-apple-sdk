//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

class ExtendableCrashReporterMock: ExtendableCrashReporter {
    var didCallAppendCrashInfo: Bool = false
    func appendCrashInfo(key: String, value: String) {
        didCallAppendCrashInfo = true
    }

    public func mergeCrashInfo(map: [String: String]) {
        map.forEach { key, value in
            appendCrashInfo(key: key, value: value)
        }
    }

    var currentSessionId: String?
    func install(context: EmbraceCommonInternal.CrashReporterContext, logger: EmbraceCommonInternal.InternalLogger) {}
    func getLastRunState() -> EmbraceCommonInternal.LastRunState {
        .unavailable
    }
    func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {}
    func deleteCrashReport(id: Int) {}
    var onNewReport: ((EmbraceCrashReport) -> Void)?
    var disableMetricKitReports: Bool = false
}
