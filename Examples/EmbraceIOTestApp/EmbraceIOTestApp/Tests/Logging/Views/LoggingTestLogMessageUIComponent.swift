//
//  LoggingTestLogMessageUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct LoggingTestLogMessageUIComponent: View {
    @EnvironmentObject var logExporter: TestLogRecordExporter
    @State private var testReport = TestReport()
    @State private var readyToTest: Bool = false
    @State private var viewDidLoadSimulated: Bool = false
    @State private var reportPresented: Bool = false
    @State private var logMessage: String = "A Test Message"
    var body: some View {
        VStack(alignment: .leading) {
            Text("Logging Message")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("Enter a message to log", text: $logMessage)
                .font(.embraceFont(size: 18))
                .backgroundStyle(.red)
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())

            TestComponentView(
                testResult: $testReport.result,
                readyForTest: .constant(testReport.result != .testing),
                testName: "Perform ERROR Log Message Test",
                testAction: {
                    readyToTest = false
                    testReport.result = .testing
                    logExporter.clearAll()
                    Embrace.client?.log(logMessage, severity: .error)
                })
        }
        .onChange(of: logExporter.state) { _, newValue in
            switch newValue {
            case .clear:
                readyToTest = testReport.result != .testing
            case .ready:
                if testReport.result == .testing {
                    testReport = logExporter.performTest(LoggingErrorMessageTest(logMessage))
                    print("Log Exported")
                    reportPresented.toggle()
                } else {
                    readyToTest = true
                }
            case .testing, .waiting:
                readyToTest = false
            }
        }
        .onAppear() {
            readyToTest = Embrace.client?.state == .started
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
