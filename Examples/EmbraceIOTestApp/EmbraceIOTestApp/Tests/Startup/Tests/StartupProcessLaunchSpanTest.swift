//
//  StartupProcessLaunchSpanTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class StartupProcessLaunchSpanTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-process-launch"] }
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

        testItems.append(.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "exists"))
        testItems.append(evaluate("emb.type", expecting: "perf", on: setupSpan.attributes))

        if let embPrivate = setupSpan.attributes["emb.private"]?.description {
            testItems.append(.init(target: "emb.private value", expected: "true", recorded: embPrivate))
        } else {
            testItems.append(.init(target: "emb.private attribute", expected: "exists", recorded: "missing", result: .fail))
        }

        MetadataResourceTest.testMetadataInclussion(on: setupSpan.resource, testItems: &testItems)

        return .init(items: testItems)
    }
}
