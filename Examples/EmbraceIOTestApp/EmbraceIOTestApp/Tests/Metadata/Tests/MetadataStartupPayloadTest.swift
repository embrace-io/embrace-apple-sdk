//
//  MetadataStartupPayloadTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class MetadataStartupPayloadTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-sdk-start-process"] }
    var requiresCleanup: Bool { false }
    var runImmediatelyIfSpansFound: Bool { true }
    var testType: TestType { .Spans }
    private var testRelevantSpanName: String {
        testRelevantPayloadNames[0]
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let startSpan = spans.first, startSpan.name == testRelevantSpanName else {
            return .init(items: [.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)])
        }

        testItems.append(evaluate("emb.type", expecting: "perf", on: startSpan.attributes))

        MetadataResourceTest.testMetadataInclussion(on: startSpan.resource, testItems: &testItems)

        return .init(items: testItems)
    }
}
