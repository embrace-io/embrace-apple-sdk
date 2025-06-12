//
//  StartupSetupPayloadTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class StartupSetupPayloadTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-app-pre-main-init"] }
    var requiresCleanup: Bool { false }
    var runImmediatelyIfSpansFound: Bool { true }
    var testType: TestType { .Spans }
    private var testRelevantSpanName: String {
        testRelevantPayloadNames[0]
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let setupSpan = spans.first, setupSpan.name == testRelevantSpanName else {
            return .init(items: [.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)])
        }

        testItems.append(evaluate("emb.type", expecting: "sys.startup", on: setupSpan.attributes))
        testItems.append(evaluate("isPrewarmed", expectedToExist: true, on: setupSpan.attributes))
        MetadataResourceTest.testMetadataInclussion(on: setupSpan.resource, testItems: &testItems)

        return .init(items: testItems)
    }
}
