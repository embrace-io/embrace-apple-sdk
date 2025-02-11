//
//  LoggingErrorMessageTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class LoggingErrorMessageTest: PayloadTest {
    var testRelevantSpanName: String { "" }
    var testType: TestType { .Logs }
    var loggedMessage: String

    init(_ loggedMessage: String) {
        self.loggedMessage = loggedMessage
    }

    func test(logs: [ReadableLogRecord]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let log = logs.first (where: { $0.body?.description == loggedMessage })
        else {
            testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "exists", result: .success))
        return .init(items: testItems)
    }

}
