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
    var testRelevantPayloadNames: [String] {
        switch captureType {
        case .manual:
            return ["emb-swiftui.view.TestDummyView.body",
                    "emb-swiftui.view.TestDummyView.time-to-first-render",
                    "emb-swiftui.view.TestDummyView.render-loop",
                    "emb-swiftui.view.TestDummyView.appear",
                    "emb-swiftui.view.TestDummyView.disappear"]
        case .macro:
            return ["emb-swiftui.view.SwiftUITestViewMacroCapture.body",
                    "emb-swiftui.view.SwiftUITestViewMacroCapture.time-to-first-render",
                    "emb-swiftui.view.SwiftUITestViewMacroCapture.render-loop",
                    "emb-swiftui.view.SwiftUITestViewMacroCapture.appear",
                    "emb-swiftui.view.SwiftUITestViewMacroCapture.disappear"]
        }
    }
    var testType: TestType { .Spans }
    var captureType: SwiftUICaptureType = .manual

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        testRelevantPayloadNames.forEach { name in
            let span = spans.first(where: { $0.name == name })
            testItems.append(
                .init(
                    target: "\(name) Span", expected: "exists", recorded: span != nil ? "exists" : "missing")
            )

            guard let span = span else {
                return
            }

            testItems.append(evaluate("emb.type", expecting: "perf.ui_load", on: span.attributes))

            MetadataResourceTest.testMetadataInclussion(on: span.resource, testItems: &testItems)
            testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(span.attributes))
        }

        return .init(items: testItems)
    }
}

