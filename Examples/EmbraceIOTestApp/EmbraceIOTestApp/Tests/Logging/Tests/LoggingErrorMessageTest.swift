//
//  LoggingErrorMessageTest.swift
//  EmbraceIOTestApp
//
//
import Foundation
import OpenTelemetrySdk
import EmbraceIO
import EmbraceCommonInternal

class LoggingErrorMessageTest: PayloadTest {
    var testRelevantSpanName: String { "" }
    var testType: TestType { .Logs }
    var loggedMessage: String
    var loggedMessageSeverity: LogSeverity

    init(_ loggedMessage: String, severity: LogSeverity) {
        self.loggedMessage = loggedMessage
        self.loggedMessageSeverity = severity
    }

    func runTestPreparations() {
        Embrace.client?.log(loggedMessage, severity: loggedMessageSeverity)
    }

    func test(logs: [ReadableLogRecord]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let log = logs.first (where: { $0.body?.description == loggedMessage })
        else {
            testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "exists", result: .success))

        testItems.append(.init(target: "Severity", expected: loggedMessageSeverity.text, recorded: log.severity?.description ?? "", result: log.severity?.description == loggedMessageSeverity.text ? .success : .fail))

        return .init(items: testItems)
    }

}
