//
//  FinishedSessionTest.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import OpenTelemetryApi
import SwiftUI

class FinishedSessionTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-session"] }
    var testType: TestType { .Spans }

    func runTestPreparations() {
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        return .init(items: testItems)
    }
}
