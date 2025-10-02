//
//  NetworkingTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import SwiftUI

class NetworkingTest: PayloadTest {
    var testURL: String = "https://embrace.io"
    var api: String = ""
    var testRelevantPayloadNames: [String] { [requestMethod.description(withApi: api)] }
    var requestMethod: URLRequestMethod = .get
    var requestBody: [String: String] = [:]

    private var fullURL: String {
        "\(testURL)\(api)"
    }
    private var client = NetworkingTestClient()

    func runTestPreparations() {

        Task {
            switch requestMethod {
            case .get:
                await client.makeTestNetworkCall(to: fullURL)
            default:
                await client.makeTestUploadRequest(to: fullURL, method: requestMethod, body: requestBody)
            }
        }
    }

    func test(spans: [SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        let (existenceReportItem, networkCallSpan) = evaluateSpanExistence(
            identifiedBy: fullURL, underAttributeKey: "url.full", on: spans)
        testItems.append(existenceReportItem)

        guard let networkCallSpan = networkCallSpan else {
            return .init(items: testItems)
        }

        testItems.append(evaluate("emb.type", expecting: "perf.network_request", on: networkCallSpan.attributes))
        testItems.append(
            evaluate("http.request.method", expecting: requestMethod.description, on: networkCallSpan.attributes))

        if case .success(let code) = client.status {
            testItems.append(
                evaluate("http.response.status_code", expecting: "\(code)", on: networkCallSpan.attributes))
        } else {
            testItems.append(.init(target: "Request Status Code", expected: "Found", recorded: "Missing"))
        }

        if requestMethod != .get && requestBody.keys.count > 0 {
            let bodySize = Int(networkCallSpan.attributes["http.request.body.size"]?.description ?? "") ?? 0
            testItems.append(
                .init(
                    target: "http.request.body.size", expected: "Bigger than 0", recorded: "\(bodySize)",
                    result: bodySize > 0 ? .success : .fail))
        }

        MetadataResourceTest.testMetadataInclussion(on: networkCallSpan.resource, testItems: &testItems)
        testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(networkCallSpan.attributes))

        return .init(items: testItems)
    }
}
