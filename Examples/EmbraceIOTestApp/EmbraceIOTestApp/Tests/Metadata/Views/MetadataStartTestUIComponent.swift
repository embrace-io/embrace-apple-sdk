//
//  MetadataStartTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct MetadataStartTestUIComponent: View {
    @Environment(TestSpanExporter.self) private var spanExporter
    @State private var testResult: TestResult = .unknown
    @State var report = TestReport(items: [])
    @State var readyToTest: Bool = false
    @State private var reportPresented: Bool = false
    var body: some View {
        VStack {
//            TestComponentView(
//                testResult: $testResult,
//                readyForTest: $readyToTest,
//                testName: "Startup Test",
//                testAction: {
//                    report = spanExporter.performTest(MetadataStartTest())
//                    reportPresented.toggle()
//                })
//            .accessibilityIdentifier("startupTestButton")
        }
//        .onChange(of: spanExporter.state) { _, newValue in
//            readyToTest = newValue == .ready
//        }
        .sheet(isPresented: $reportPresented) {
            TestReportCard(report: report)
        }
    }
}
