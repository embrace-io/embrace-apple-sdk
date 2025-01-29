//
//  MetadataStartTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct MetadataStartTestUIComponent: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State var report = TestReport()
    @State var readyToTest: Bool = false
    @State private var reportPresented: Bool = false
    var body: some View {
        VStack {
            TestComponentView(
                testResult: $report.result,
                readyForTest: $readyToTest,
                testName: "Startup Test",
                testAction: {
                    report = spanExporter.performTest(MetadataStartTest(), clearAfterTest: false)
                    reportPresented.toggle()
                })
            .accessibilityIdentifier("startupTestButton")
        }
        .onChange(of: spanExporter.state) { _, newValue in
            readyToTest = newValue == .ready
        }
        .sheet(isPresented: $reportPresented) {
            TestReportCard(report: $report)
        }
    }
}
