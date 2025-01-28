//
//  MetadataTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk

class MetadataStartTest: PayloadTest {
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestItem]()
        let startSpanName = "emb-sdk-start"

        guard let startSpan = spans.first (where: { $0.name == startSpanName })
        else {
            testItems.append(.init(target: startSpanName, expected: "exists", recorded: "missing", result: .fail))
            return .init(result: .fail, testItems: testItems)
        }

        testItems.append(.init(target: startSpanName, expected: "exists", recorded: "exists", result: .pass))
        testItems.append(evaluate("emb.type", expecting: "perf", on: startSpan.attributes))

        return .init(result: testResult(from: testItems), testItems: testItems)
    }
}

class MetadataSetupTest: PayloadTest {
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestItem]()
        let setupSpanName = "emb-setup"

        guard let setupSpan = spans.first (where: { $0.name == setupSpanName })
        else {
            testItems.append(.init(target: setupSpanName, expected: "exists", recorded: "missing", result: .fail))
            return .init(result: .fail, testItems: testItems)
        }

        testItems.append(.init(target: setupSpanName, expected: "exists", recorded: "exists", result: .pass))
        testItems.append(evaluate("emb.type", expecting: "perf", on: setupSpan.attributes))
        testItems.append(evaluate("emb.private", expecting: "true", on: setupSpan.attributes))

        return .init(result: testResult(from: testItems), testItems: testItems)
    }
}
