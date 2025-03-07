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
    var testRelevantSpanName: String = ""
    var testType: TestType { .Logs }
    var requiresCleanup: Bool { true }
    var loggedMessage: String {
        didSet {
            testRelevantSpanName = loggedMessage
        }
    }
    var loggedMessageSeverity: LogSeverity
    var stackTraceBehavior: StackTraceBehavior = .default

    init(_ loggedMessage: String, severity: LogSeverity) {
        self.loggedMessage = loggedMessage
        self.loggedMessageSeverity = severity
    }

    func runTestPreparations() {
        Embrace.client?.log(loggedMessage, severity: loggedMessageSeverity, stackTraceBehavior: stackTraceBehavior)
    }

    func test(logs: [ReadableLogRecord]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let log = logs.first (where: { $0.body?.description == loggedMessage })
        else {
            testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "exists", result: .success))

        testItems.append(.init(target: "Severity", expected: loggedMessageSeverity.text, recorded: log.severity?.description))

        testItems.append(.init(target: "Stacktrace", expected: stacktraceExpected ? "found" : "missing", recorded: log.attributes["emb.stacktrace.ios"] != nil ? "found" : "missing"))

        return .init(items: testItems)
    }

    private var stacktraceExpected: Bool {
        switch stackTraceBehavior {
        case .notIncluded:
            return false
        case .default:
            switch loggedMessageSeverity {
            case .trace, .debug, .info, .fatal:
                return false
            case .warn, .error:
                return true
            }
        }
    }

}
