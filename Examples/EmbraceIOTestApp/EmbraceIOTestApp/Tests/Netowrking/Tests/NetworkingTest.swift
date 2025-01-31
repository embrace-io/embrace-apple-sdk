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
    var testRelevantSpanName: String { "GET " }
    func test(spans: [SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        let (existenceReportItem, networkCallSpan) = evaluateSpanExistence(identifiedBy: testURL, underAttributeKey: "url.full", on: spans)
        testItems.append(existenceReportItem)

        guard let networkCallSpan = networkCallSpan else {
            return .init(items: testItems)
        }

        testItems.append(evaluate("emb.type", expecting: "perf.network_request", on: networkCallSpan.attributes))
        testItems.append(evaluate("http.request.method", expecting: "GET", on: networkCallSpan.attributes))
        testItems.append(evaluate("http.response.status_code", expecting: "\(statusCode)", on: networkCallSpan.attributes))

        return .init(items: testItems)
    }
}
