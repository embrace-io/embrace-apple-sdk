//
//  MetadataSetupTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct MetadataSetupTestUIComponent: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State var report = TestReport()
    @State var readyToTest: Bool = false
    @State private var reportPresented: Bool = false
    var body: some View {
        VStack {
            TestComponentView(
                testResult: $report.result,
                readyForTest: $readyToTest,
                testName: "Setup Test",
                testAction: {
                    report = spanExporter.performTest(MetadataSetupTest(), clearAfterTest: false)
                    reportPresented.toggle()
                })
            .accessibilityIdentifier("setupTestButton")
        }
        .onChange(of: spanExporter.state) { _, newValue in
            readyToTest = newValue == .ready
        }
        .sheet(isPresented: $reportPresented) {
            TestReportCard(report: $report)
        }
    }
}
