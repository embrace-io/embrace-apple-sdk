//
//  ViewControllerViewDidLoadTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi
import SwiftUI

class ViewControllerViewDidLoadTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-view-did-load"] }
    var testType: TestType { .Spans }

    func runTestPreparations() {
        let a = TestViewController()
        a.viewDidLoad()
    }

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

        MetadataResourceTest.testMetadataInclussion(on: viewDidLoadSpan.resource, testItems: &testItems)
        testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(viewDidLoadSpan.attributes))

        return .init(items: testItems)
    }
}

class TestViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
