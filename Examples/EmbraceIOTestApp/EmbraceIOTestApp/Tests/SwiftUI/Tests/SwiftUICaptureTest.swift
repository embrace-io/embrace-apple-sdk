//
//  SwiftUICaptureTest.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

class SwiftUICaptureTest: PayloadTest {
    var testRelevantPayloadNames: [String] {
        var spans = [
            "emb-swiftui.view.\(viewName).time-to-first-render",
            "emb-swiftui.view.\(viewName).appear",
            "emb-swiftui.view.\(viewName).disappear"
        ]
        if tracksBodyEvaluations {
            spans.append("emb-swiftui.view.\(viewName).body")
            spans.append("emb-swiftui.view.\(viewName).render-loop")
        }
        if contentComplete {
            spans.append("emb-swiftui.view.\(viewName).time-to-first-content-complete")
        }

        return spans
    }

    /// Body and render-loop spans are opt-in, so they are only expected from the capture paths
    /// that pass `trackBodyEvaluations: true`. The `@EmbraceTrace` macro takes no arguments and
    /// therefore has no opt-in, so it emits neither.
    private var tracksBodyEvaluations: Bool {
        switch captureType {
        case .manual, .embraceView:
            return true
        case .macro:
            return false
        }
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
    var contentComplete: Bool = false

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        testRelevantPayloadNames.forEach { name in
            print("Testing: \(name)")
            let span = spans.first(where: { $0.name == name })
            testItems.append(
                .init(
                    target: "\(name) Span", expected: "exists", recorded: span != nil ? "exists" : "missing")
            )

            guard let span = span else {
                return
            }

            testItems.append(evaluate("emb.type", expecting: "perf.ui_load", on: span.attributes))

            attributes.keys.forEach { key in
                if let value = attributes[key] {
                    testItems.append(evaluate(key, expecting: value, on: span.attributes))
                } else {
                    testItems.append(.init(target: "Attribute \(key)", expected: "Some Value", recorded: "Nil Value"))
                }
            }

            testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(span.attributes))
        }

        return .init(items: testItems)
    }
}
