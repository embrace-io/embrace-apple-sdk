//
//  MetadataTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class MetadataStartTest: PayloadTest {
    var testRelevantSpanName: String { "emb-sdk-start" }
    var testType: TestType { .Spans }
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let startSpan = spans.first, startSpan.name == testRelevantSpanName else {
            return .init(items: [.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)])
        }

        testItems.append(evaluate("emb.type", expecting: "perf", on: startSpan.attributes))

        return .init(items: testItems)
    }
}

class MetadataSetupTest: PayloadTest {
    var testRelevantSpanName: String { "emb-setup" }
    var testType: TestType { .Spans }
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        guard let setupSpan = spans.first, setupSpan.name == testRelevantSpanName else {
            return .init(items: [.init(target: "\(testRelevantSpanName) span", expected: "exists", recorded: "missing", result: .fail)])
        }

        testItems.append(evaluate("emb.type", expecting: "perf", on: setupSpan.attributes))
        testItems.append(evaluate("emb.private", expecting: "true", on: setupSpan.attributes))

        return .init(items: testItems)
    }
}
