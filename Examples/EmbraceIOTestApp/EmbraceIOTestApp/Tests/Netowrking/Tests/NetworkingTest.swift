//
//  NetworkingTest.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

class NetworkingTest: PayloadTest {
    var testURL: String
    var statusCode: Int
    init(testURL: String, statusCode: Int) {
        self.testURL = testURL
        self.statusCode = statusCode
    }

    func test(spans: [SpanData]) -> TestReport {
        var testItems = [TestReportItem]()
        let spanName = "GET "
        guard let networkCallSpan = spans.first (where: { $0.name == spanName && $0.attributes["url.full"]?.description == testURL }) else {
            testItems.append(.init(target: "\(spanName)\(testURL)", expected: "exists", recorded: "missing", result: .fail))
            return .init(result: .fail, items: testItems)
        }

        testItems.append(.init(target: "\(spanName)\(testURL)", expected: "exists", recorded: "exists", result: .success))
        testItems.append(evaluate("emb.type", expecting: "perf.network_request", on: networkCallSpan.attributes))
        testItems.append(evaluate("http.request.method", expecting: "GET", on: networkCallSpan.attributes))
        testItems.append(evaluate("http.response.status_code", expecting: "\(statusCode)", on: networkCallSpan.attributes))

        return .init(result: testResult(from: testItems), items: testItems)
    }
}
