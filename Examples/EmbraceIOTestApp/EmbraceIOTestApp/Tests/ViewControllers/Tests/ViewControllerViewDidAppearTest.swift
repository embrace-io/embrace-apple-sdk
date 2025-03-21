//
//  ViewControllerViewDidAppearTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi
import SwiftUI

class ViewControllerViewDidAppearTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-view-did-load", "emb-view-will-appear", "emb-view-is-appearing", "emb-view-did-appear"] }
    var requiresCleanup: Bool { true }
    var testType: TestType { .Spans }

    func runTestPreparations() {
        let a = TestViewController()
        a.viewDidLoad()
        a.viewWillAppear(true)
        a.viewDidAppear(true)
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        /// spans exported after the cleanup process might showup here so filtering here is required for now.
        let relevantSpans = spans.filter { span in
            span.attributes["view.name"]?.description == "TestViewController"
        }

        let viewDidLoadSpan = relevantSpans.first(where: { $0.name == "emb-view-did-load" })
        let viewWillAppearSpan = relevantSpans.first(where: { $0.name == "emb-view-will-appear" })
        let viewIsAppearingSpan = relevantSpans.first(where: { $0.name == "emb-view-is-appearing" })
        let viewDidAppearSpan = relevantSpans.first(where: { $0.name == "emb-view-did-appear" })

        testItems.append(.init(target: "viewDidLoad Span", expected: "exists", recorded: viewDidLoadSpan != nil ? "exists" : "missing"))
        testItems.append(.init(target: "viewWillAppear Span", expected: "exists", recorded: viewDidLoadSpan != nil ? "exists" : "missing"))
        testItems.append(.init(target: "viewIsAppearing Span", expected: "exists", recorded: viewDidLoadSpan != nil ? "exists" : "missing"))
        testItems.append(.init(target: "viewDidAppear Span", expected: "exists", recorded: viewDidLoadSpan != nil ? "exists" : "missing"))

        guard
            let viewDidLoadSpan = viewDidLoadSpan,
            let viewWillAppearSpan = viewWillAppearSpan,
            let viewIsAppearingSpan = viewIsAppearingSpan,
            let viewDidAppearSpan = viewDidAppearSpan
        else {
            return .init(items: testItems)
        }

        testItems.append(.init(target: "viewDidLoad Span Ended", expected: "yes", recorded: viewDidLoadSpan.hasEnded ? "yes" : "no"))
        testItems.append(.init(target: "viewWillAppear Span Ended", expected: "yes", recorded: viewWillAppearSpan.hasEnded ? "yes" : "no"))
        testItems.append(.init(target: "viewIsAppearing Span Ended", expected: "yes", recorded: viewIsAppearingSpan.hasEnded ? "yes" : "no"))
        testItems.append(.init(target: "viewDidAppear Span Ended", expected: "yes", recorded: viewDidAppearSpan.hasEnded ? "yes" : "no"))

        let order = [viewDidAppearSpan, viewIsAppearingSpan, viewWillAppearSpan, viewDidLoadSpan].sorted { lhs, rhs in
            lhs.startTime < rhs.startTime
        }

        testItems.append(.init(target: "Span Trigger Order", expected: "didLoad, willAppear, isAppearing, didAppear", recorded: spanOrderString(order)))

        return .init(items: testItems)
    }

    private func spanOrderString(_ spans: [SpanData]) -> String {
        var orderString = ""

        spans.forEach { span in
            if orderString != "" {
                orderString = "\(orderString), "
            }
            switch span.name {
            case "emb-view-did-load":
                orderString = "\(orderString)didLoad"
            case "emb-view-will-appear":
                orderString = "\(orderString)willAppear"
            case "emb-view-is-appearing":
                orderString = "\(orderString)isAppearing"
            case "emb-view-did-appear":
                orderString = "\(orderString)didAppear"
            default:
                orderString = "\(orderString)\(span.name)"
            }
        }

        return orderString
    }
}
