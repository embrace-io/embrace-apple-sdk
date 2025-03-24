//
//  NetworkingTest.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

class NetworkingTest: PayloadTest {
    var testURL: String = "https://embrace.io"
    private var client = NetworkingTestClient()
    var testRelevantPayloadNames: [String] { [requestMethod.text] }
    var requestMethod: URLRequestMethod = .get
    func runTestPreparations() {
        Task {
            await client.makeTestNetworkCall(to: testURL)
        }
    }

    func test(spans: [SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        let (existenceReportItem, networkCallSpan) = evaluateSpanExistence(identifiedBy: testURL, underAttributeKey: "url.full", on: spans)
        testItems.append(existenceReportItem)

        guard let networkCallSpan = networkCallSpan else {
            return .init(items: testItems)
        }

        testItems.append(evaluate("emb.type", expecting: "perf.network_request", on: networkCallSpan.attributes))
        testItems.append(evaluate("http.request.method", expecting: "GET", on: networkCallSpan.attributes))
        testItems.append(evaluate("http.response.status_code", expecting: "200", on: networkCallSpan.attributes))

        return .init(items: testItems)
    }
}
