//
//  StartupStartupProcessSpanTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class StartupStartupProcessSpanTest: PayloadTest {
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
            return .init(items: [
                .init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)
            ])
        }

        testItems.append(.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "exists"))
        testItems.append(evaluate("emb.type", expecting: "perf", on: startSpan.attributes))

        MetadataResourceTest.testMetadataInclussion(on: startSpan.resource, testItems: &testItems)
        testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(startSpan.attributes))

        return .init(items: testItems)
    }
}
