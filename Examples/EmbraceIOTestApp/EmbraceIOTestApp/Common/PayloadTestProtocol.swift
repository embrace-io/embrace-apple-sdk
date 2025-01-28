//
//  PayloadTestProtocol.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi

protocol PayloadTest {
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport
    func evaluate(_ target: String, expecting: String, on: [String: AttributeValue]) -> TestReportItem
    func testResult(from items: [TestReportItem]) -> TestResult
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

    func testResult(from items: [TestReportItem]) -> TestResult {
        items.contains(where: { $0.result == .fail }) ? .fail : .success
    }
}
