//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

class CrashReporterMock: CrashReporter {
    var sdkVersion: String?

    func appendCrashInfo(key: String, value: String) {
    }

    func getCrashInfo(key: String) -> String? {
        nil
    }

    var basePath: String?

    var currentSessionId: String?
    var mockReports: [EmbraceCrashReport]

    var onNewReport: ((EmbraceCrashReport) -> Void)?

    var disableMetricKitReports: Bool = false

    init(
        currentSessionId: String? = nil,
        crashSessionId: String? = nil,
        mockReports: [EmbraceCrashReport]? = nil
    ) {
        self.currentSessionId = currentSessionId
        self.mockReports =
            mockReports ?? [
                EmbraceCrashReport(
                    payload: "test",
                    provider: "mock",
                    internalId: 123,
                    sessionId: crashSessionId ?? SessionIdentifier.random.toString,
                    timestamp: Date()
                )
            ]
    }

    public var forcedLastRunState: LastRunState = .crash
    func getLastRunState() -> LastRunState {
        return forcedLastRunState
    }

    func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {
        completion(mockReports)
    }

    func deleteCrashReport(_ report: EmbraceCrashReport) {
        mockReports.removeAll { r in
            r.internalId == report.internalId
        }
    }

    func install(context: CrashReporterContext) throws {

    }
}
