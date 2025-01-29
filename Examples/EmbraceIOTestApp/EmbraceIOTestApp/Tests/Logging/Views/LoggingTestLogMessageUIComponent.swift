//
//  LoggingTestLogMessageUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct LoggingTestLogMessageUIComponent: View {
    @EnvironmentObject var logExporter: TestLogRecordExporter
    @State private var testReport = TestReport()
    @State private var readyToTest: Bool = false
    @State private var viewDidLoadSimulated: Bool = false
    @State private var reportPresented: Bool = false
    var body: some View {
        TestComponentView(
            testResult: $testReport.result,
            readyForTest: $readyToTest,
            testName: "Perform Log Message Test",
            testAction: {
                readyToTest = false
                testReport.result = .testing
            })
        .onChange(of: logExporter.state) { _, newValue in
            switch newValue {
            case .clear:
                if testReport.result == .testing {
//                    let a = TestViewController()
//                    a.viewDidLoad()
                } else {
                    readyToTest = true
                }
            case .ready:
                if testReport.result == .testing {
                    //testReport = logExporter.performTest(ViewControllerViewDidLoadTest())
                    reportPresented.toggle()
                } else {
                    readyToTest = true
                }
            case .testing, .waiting:
                readyToTest = false
            }
        }
        .onAppear() {
            readyToTest = logExporter.state != .waiting
        }
        .sheet(isPresented: $reportPresented) {
            TestReportCard(report: $testReport)
        }
    }
}

#Preview {
    let logExporter = TestLogRecordExporter()
    LoggingTestLogMessageUIComponent()
        .environmentObject(logExporter)
}
