//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

class CrashReporterMock: CrashReporter {
    var sdkVersion: String?

    var customInfo: [String: String] = [:]
    func appendCrashInfo(key: String, value: String?) {
        customInfo[key] = value
    }

    func getCrashInfo(key: String) -> String? {
        customInfo[key]
    }

    var basePath: String?

    var mockReports: [EmbraceCrashReport]

    var onNewReport: ((EmbraceCrashReport) -> Void)?

    var disableMetricKitReports: Bool = false

    init(
        currentSessionId: String? = nil,
        crashSessionId: String? = nil,
        mockReports: [EmbraceCrashReport]? = nil
    ) {
        customInfo[CrashReporterInfoKey.sessionId] = currentSessionId

        self.mockReports =
            mockReports ?? [
                EmbraceCrashReport(
                    payload: "test",
                    provider: "mock",
                    internalId: 123,
                    sessionId: crashSessionId ?? EmbraceIdentifier.random.stringValue,
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

    func fetchUnsentCrashReports() async -> [EmbraceCrashReport] {
        await withCheckedContinuation { continuation in
            fetchUnsentCrashReports { reports in
                continuation.resume(returning: reports)
            }
        }
    }

    func deleteCrashReport(_ report: EmbraceCrashReport) {
        mockReports.removeAll { r in
            r.internalId == report.internalId
        }
    }

    func install(context: CrashReporterContext) throws {

    }
}
