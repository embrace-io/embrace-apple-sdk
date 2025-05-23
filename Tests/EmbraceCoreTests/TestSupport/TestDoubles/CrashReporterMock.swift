//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

class CrashReporterMock: CrashReporter {

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
        self.mockReports = mockReports ?? [
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

    func deleteCrashReport(id: Int) {
        mockReports.removeAll { report in
            report.internalId == id
        }
    }
    
    func install(context: CrashReporterContext, logger: InternalLogger) {

    }
}
