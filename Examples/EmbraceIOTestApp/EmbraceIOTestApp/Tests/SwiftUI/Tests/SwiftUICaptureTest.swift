//
//  SwiftUICaptureTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi
import SwiftUI
import EmbraceIO

class SwiftUICaptureTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-view-did-load"] }
    var testType: TestType { .Spans }

    func runTestPreparations() {
   //     let testView = SwiftUITestView()
//        let hostController = UIHostingController(rootView: testView)
//        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//        window.rootViewController = hostController
//        window.makeKeyAndVisible()
//
//        hostController.loadViewIfNeeded()
//        hostController.view.layoutIfNeeded()
//
//        window.isHidden = true
     //   testView.body.onAppear()
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

