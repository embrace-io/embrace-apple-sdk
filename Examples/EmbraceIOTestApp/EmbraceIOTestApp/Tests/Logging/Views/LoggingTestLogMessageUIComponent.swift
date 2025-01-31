//
//  LoggingTestLogMessageUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct LoggingTestLogMessageUIComponent: View {
    @EnvironmentObject var logExporter: TestLogRecordExporter
    @State private var testResult: TestResult = .unknown
    @State private var testReport = TestReport(items: [])
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
                testResult: $testResult,
                readyForTest: .constant(testResult != .testing),
                testName: "Perform ERROR Log Message Test",
                testAction: {
                    readyToTest = false
                    testResult = .testing
                    logExporter.clearAll()
                    Embrace.client?.log(logMessage, severity: .error)
                })
        }
        .onChange(of: logExporter.state) { _, newValue in
            switch newValue {
            case .clear:
                readyToTest = testResult != .testing
            case .ready:
                if testResult == .testing {
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
