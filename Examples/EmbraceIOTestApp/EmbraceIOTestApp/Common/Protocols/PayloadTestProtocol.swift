//
//  PayloadTestProtocol.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi

protocol PayloadTest {
    var testRelevantSpanName: String { get }
    var requiresCleanup: Bool { get }
    var runImmediatelyIfSpansFound: Bool { get }
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport
    func test(logs: [ReadableLogRecord]) -> TestReport
    func evaluate(_ target: String, expecting: String, on: [String: AttributeValue]) -> TestReportItem
    func evaluateSpanExistence(identifiedBy id: String, underAttributeKey key: String, on spans: [SpanData]) -> (TestReportItem, SpanData?)
    func evaluateLogExistence(withMessage message: String, on logs: [ReadableLogRecord]) -> (TestReportItem, ReadableLogRecord?)
    func runTestPreparations()
}

extension PayloadTest {
    func evaluate(_ target: String, expecting expected: String, on attributes: [String: AttributeValue]) -> TestReportItem {
        guard let value = attributes[target] else {
            return .init(target: target, expected: expected, recorded: "missing", result: .fail)
        }
        let recorded = value.description
        let result: TestResult = recorded == expected ? .success : .fail

        return .init(target: target, expected: expected, recorded: recorded, result: result)
    }

    func evaluateSpanExistence(identifiedBy id: String, underAttributeKey key: String, on spans: [SpanData]) -> (TestReportItem, SpanData?) {
        guard let targetSpan = spans.first (where: { $0.attributes[key]?.description == id }) else {
            return (.init(target: "\(id)'s Span", expected: "exists", recorded: "missing", result: .fail), nil)
        }

        return (.init(target: "\(id)'s Span", expected: "exists", recorded: "exists", result: .success), targetSpan)
    }

    func evaluateLogExistence(withMessage message: String, on logs: [ReadableLogRecord]) -> (TestReportItem, ReadableLogRecord?) {
        guard let log = logs.first (where: { $0.body?.description == message }) else {
            return (.init(target: "\(message)'s log", expected: "exists", recorded: "missing", result: .fail), nil)
        }

        return (.init(target: "\(message)'s log", expected: "exists", recorded: "exists", result: .success), log)
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport { .init(items: []) }

    func test(logs: [ReadableLogRecord]) -> TestReport { .init(items: []) }

    func runTestPreparations() { }

    var requiresCleanup: Bool { true }

    var runImmediatelyIfSpansFound: Bool { false }
}
