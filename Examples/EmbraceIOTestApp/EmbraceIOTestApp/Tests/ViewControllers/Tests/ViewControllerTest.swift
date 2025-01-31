//
//  ViewControllerTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi

class ViewControllerViewDidLoadTest: PayloadTest {
    var testRelevantSpanName: String { "emb-view-did-load" }
    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        let (existenceReport, viewDidLoadSpan) = evaluateSpanExistence(identifiedBy: "TestViewController", underAttributeKey: "view.name", on: spans)
        testItems.append(existenceReport)
        guard let viewDidLoadSpan = viewDidLoadSpan else {
            return .init(items: testItems)
        }

        testItems.append(evaluate("emb.type", expecting: "perf.ui_load", on: viewDidLoadSpan.attributes))
        testItems.append(evaluate("view.title", expecting: "TestViewController", on: viewDidLoadSpan.attributes))
        testItems.append(evaluate("view.name", expecting: "TestViewController", on: viewDidLoadSpan.attributes))

        return .init(items: testItems)
    }
}
