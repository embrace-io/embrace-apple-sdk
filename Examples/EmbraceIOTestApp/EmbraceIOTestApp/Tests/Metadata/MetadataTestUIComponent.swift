//
//  MetadataTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct MetadataTestUIComponent: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State var setupTestReport = TestReport()
    @State var startTestReport = TestReport()
    @State var readyToTest: Bool = false
    @State private var startReportPresented: Bool = false
    @State private var setupReportPresented: Bool = false
    var body: some View {
        VStack {
            TestComponentView(
                testResult: $startTestReport.result,
                readyForTest: $readyToTest,
                testName: "Startup Test",
                testAction: {
                    startTestReport = spanExporter.performTest(MetadataStartTest(), clearAfterTest: false)
                    startReportPresented.toggle()
                })
            TestComponentView(
                testResult: $setupTestReport.result,
                readyForTest: $readyToTest,
                testName: "Setup Test",
                testAction: {
                    setupTestReport = spanExporter.performTest(MetadataSetupTest(), clearAfterTest: false)
                    setupReportPresented.toggle()
                })
        }
        .onChange(of: spanExporter.state) { _, newValue in
            readyToTest = newValue == .ready
        }
        .sheet(isPresented: $startReportPresented) {
            TestReportCard(report: $startTestReport)
        }
        .sheet(isPresented: $setupReportPresented) {
            TestReportCard(report: $setupTestReport)
        }
    }
}
