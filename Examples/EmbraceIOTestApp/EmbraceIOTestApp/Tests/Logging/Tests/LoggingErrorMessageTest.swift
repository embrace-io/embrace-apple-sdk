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
    var testRelevantPayloadNames: [String] { [loggedMessage] }
    var testType: TestType { .Logs }
    var requiresCleanup: Bool { true }
    var loggedMessage: String
    var loggedMessageSeverity: LogSeverity
    var logProperties: [String: String] = [:]
    var stackTraceBehavior: StackTraceBehavior = .default
    var includeAttachment: Bool = false
    var attachmentSize: Int = 0
    init(_ loggedMessage: String, severity: LogSeverity) {
        self.loggedMessage = loggedMessage
        self.loggedMessageSeverity = severity
    }

    func runTestPreparations() {
        if includeAttachment {
            Embrace.client?.log(loggedMessage,
                                severity: loggedMessageSeverity,
                                attachment: createDummyDataOfSize(attachmentSize),
                                attributes: logProperties,
                                stackTraceBehavior: stackTraceBehavior)
        } else {
            Embrace.client?.log(loggedMessage,
                                severity: loggedMessageSeverity,
                                attributes: logProperties,
                                stackTraceBehavior: stackTraceBehavior)
        }
    }

    func test(logs: [ReadableLogRecord]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let log = logs.first(where: { $0.body?.description == loggedMessage })
        else {
            testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "missing", result: .fail))
            return .init(items: testItems)
        }

        testItems.append(.init(target: loggedMessage, expected: "exists", recorded: "exists", result: .success))

        testItems.append(.init(target: "Severity", expected: loggedMessageSeverity.text, recorded: log.severity?.description))

        testItems.append(.init(target: "Stacktrace", expected: stacktraceExpected ? "found" : "missing", recorded: log.attributes["emb.stacktrace.ios"] != nil ? "found" : "missing"))

        if includeAttachment {
            testItems.append(evaluate("emb.attachment_id", expectedToExist: true, on: log.attributes))
            testItems.append(evaluate("emb.attachment_size", expecting: "\(attachmentSize)", on: log.attributes))

            if attachmentSize > 1048576 {
                testItems.append(evaluate("emb.attachment_error_code", expecting: "ATTACHMENT_TOO_LARGE", on: log.attributes))
            } else {
                testItems.append(evaluate("emb.attachment_error_code", expectedToExist: false, on: log.attributes))
            }
        } else {
            testItems.append(evaluate("emb.attachment_id", expectedToExist: false, on: log.attributes))
            testItems.append(evaluate("emb.attachment_size", expectedToExist: false, on: log.attributes))
            testItems.append(evaluate("emb.attachment_error_code", expectedToExist: false, on: log.attributes))
        }

        logProperties.forEach { property in
            testItems.append(evaluate(property.key, expecting: property.value, on: log.attributes))
        }

        MetadataResourceTest.testMetadataInclussion(on: log.resource, testItems: &testItems)

        return .init(items: testItems)
    }

    private var stacktraceExpected: Bool {
        switch stackTraceBehavior {
        case .notIncluded:
            return false
        case .default, .custom:
            switch loggedMessageSeverity {
            case .trace, .debug, .info, .fatal:
                return false
            case .warn, .error:
                return true
            }
        }
    }

    /// Size in bytes of the dummy data
    private func createDummyDataOfSize(_ size: Int) -> Data {
        let bytes = [UInt32](repeating: 0, count: size/4).map { _ in arc4random() }
        return Data(bytes: bytes, count: size)
    }
}
