//
//  ViewControllerTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi

class ViewControllerViewDidLoadTest: PayloadTest {
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestItem]()
        let spanName = "emb-view-did-load"
        guard let viewDidLoadSpan = spans.first (where: { $0.name == spanName })
        else {
            testItems.append(.init(target: spanName, expected: "exists", recorded: "missing", result: .fail))
            return .init(result: .fail, testItems: testItems)
        }

        testItems.append(.init(target: spanName, expected: "exists", recorded: "exists", result: .pass))
        testItems.append(evaluate("emb.type", expecting: "perf.ui_load", on: viewDidLoadSpan.attributes))
        testItems.append(evaluate("view.title", expecting: "TestViewController", on: viewDidLoadSpan.attributes))
        testItems.append(evaluate("view.name", expecting: "TestViewController", on: viewDidLoadSpan.attributes))

        return .init(result: testResult(from: testItems), testItems: testItems)
    }
}
