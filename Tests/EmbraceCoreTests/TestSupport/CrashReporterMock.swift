//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

class CrashReporterMock: CrashReporter {
    var currentSessionId: EmbraceCommon.SessionIdentifier?
    var mockReports: [EmbraceCommon.CrashReport]

    init(currentSessionId: EmbraceCommon.SessionIdentifier? = nil, mockReports: [EmbraceCommon.CrashReport]? = nil) {
        self.currentSessionId = currentSessionId
        self.mockReports = mockReports ?? [.init(ksCrashId: 123,
                                                 sessionId: .some(.random),
                                                 timestamp: Date(),
                                                 dictionary: ["some key": ["some value"]])]
    }

    func getLastRunState() -> EmbraceCommon.LastRunState {
        return .crash
    }

    func fetchUnsentCrashReports(completion: @escaping ([EmbraceCommon.CrashReport]) -> Void) {
        completion(mockReports)
    }

    func deleteCrashReport(id: Int) {
        mockReports.removeAll { report in
            report.ksCrashId == id
        }
    }

    func install(context: EmbraceCommon.CaptureServiceContext) {

    }

    func uninstall() {

    }

    func start() {

    }

    func stop() {

    }
}
