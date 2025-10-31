//
//  PayloadTestProtocol.swift
//  EmbraceIOTestApp
//
//

import EmbraceObjCUtilsInternal
import OpenTelemetryApi
import OpenTelemetrySdk

protocol PayloadTest {
    // TODO: Remove once all existing tests have been consolidated on the same view model.
    var testRelevantPayloadNames: [String] { get }

    var expectedNotificationsForTestReady: [String] { get }
    var requiresCleanup: Bool { get }
    var runImmediatelyIfSpansFound: Bool { get }
    var runImmediatelyIfLogsFound: Bool { get }
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport
    func test(logs: [ReadableLogRecord]) -> TestReport
    func test(spans: [OpenTelemetrySdk.SpanData], logs: [ReadableLogRecord]) -> TestReport
    func evaluate(_ target: String, expecting: String, on: [String: AttributeValue]) -> TestReportItem
    func evaluate(_ target: String, contains: String, on: [String: AttributeValue]) -> TestReportItem
    func evaluate(_ target: String, expectedToExist: Bool, on: [String: AttributeValue]) -> TestReportItem
    func evaluateSpanExistence(identifiedBy id: String, underAttributeKey key: String, on spans: [SpanData]) -> (
        TestReportItem, SpanData?
    )
    func evaluateLogExistence(withMessage: String, on logs: [ReadableLogRecord]) -> (TestReportItem, ReadableLogRecord?)
    func runTestPreparations()
}

extension PayloadTest {
    func evaluate(_ target: String, expecting expected: String, on attributes: [String: AttributeValue])
        -> TestReportItem
    {
        guard let value = attributes[target] else {
            return .init(target: target, expected: expected, recorded: "missing", result: .fail)
        }
        let recorded = value.description
        let result: TestResult = recorded == expected ? .success : .fail

        return .init(target: target, expected: expected, recorded: recorded, result: result)
    }

    func evaluateSpanExistence(identifiedBy id: String, underAttributeKey key: String, on spans: [SpanData]) -> (
        TestReportItem, SpanData?
    ) {
        guard let targetSpan = spans.first(where: { $0.attributes[key]?.description == id }) else {
            return (.init(target: "\(id)'s Span", expected: "exists", recorded: "missing", result: .fail), nil)
        }

        return (.init(target: "\(id)'s Span", expected: "exists", recorded: "exists", result: .success), targetSpan)
    }

    func evaluateLogExistence(withMessage message: String, on logs: [ReadableLogRecord]) -> (
        TestReportItem, ReadableLogRecord?
    ) {
        guard let log = logs.first(where: { $0.body?.description == message }) else {
            return (.init(target: "\(message)'s log", expected: "exists", recorded: "missing", result: .fail), nil)
        }

        return (.init(target: "\(message)'s log", expected: "exists", recorded: "exists", result: .success), log)
    }

    func evaluate(_ target: String, contains substring: String, on attributes: [String: AttributeValue])
        -> TestReportItem
    {
        guard let value = attributes[target] else {
            return .init(target: target, expected: target, recorded: "missing", result: .fail)
        }
        let recorded = value.description
        let result: TestResult = recorded.contains(substring) ? .success : .fail

        return .init(
            target: target, expected: "contains \(substring)", recorded: result == .success ? "found" : "missing",
            result: result)
    }

    func evaluate(_ target: String, expectedToExist: Bool = true, on attributes: [String: AttributeValue])
        -> TestReportItem
    {
        let value = attributes[target]

        let expected = expectedToExist ? "exists" : "missing"
        let recorded = value != nil ? "exists" : "missing"

        return .init(target: target, expected: expected, recorded: recorded)
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport { .init(items: []) }

    func test(logs: [ReadableLogRecord]) -> TestReport { .init(items: []) }

    func test(spans: [OpenTelemetrySdk.SpanData], logs: [ReadableLogRecord]) -> TestReport { .init(items: []) }

    func runTestPreparations() {}

    var requiresCleanup: Bool { true }

    var runImmediatelyIfSpansFound: Bool { false }

    var runImmediatelyIfLogsFound: Bool { false }

    // TODO: Remove once all existing tests have been consolidated on the same view model.
    var testRelevantPayloadNames: [String] { [] }

    // TODO: Remove default initializer when 'testRelevantPayloadNames' is removed.
    var expectedNotificationsForTestReady: [String] { [] }
}
