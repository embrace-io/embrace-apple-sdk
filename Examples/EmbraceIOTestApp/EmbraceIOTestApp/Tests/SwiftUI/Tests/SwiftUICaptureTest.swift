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
        return ["emb-swiftui.view.\(viewName).body",
                "emb-swiftui.view.\(viewName).time-to-first-render",
                "emb-swiftui.view.\(viewName).render-loop",
                "emb-swiftui.view.\(viewName).appear",
                "emb-swiftui.view.\(viewName).disappear"]
    }
    private var viewName: String {
        switch captureType {
        case .manual:
            return "TestDummyView"
        case .macro:
            return "SwiftUITestViewMacroCapture"
        case .embraceView:
            return "MyEmbraceTraceView"
        }
    }

    var testType: TestType { .Spans }
    var captureType: SwiftUICaptureType = .manual
    var attributes: [String: String] = [:]
    var loaded: SwiftUITestsLoadedState = .dontInclude

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

