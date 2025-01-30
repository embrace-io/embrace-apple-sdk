//
//  NetworkingTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct NetworkingTestUIComponent: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State private var testReport = TestReport()
    @State private var readyToTest: Bool = false
    @State private var viewDidLoadSimulated: Bool = false
    @State private var reportPresented: Bool = false
    @State private var client = NetworkingTestClient()
    private var testURL = "https://embrace.io"

    private var statusCode: Int {
        switch client.status {
        case .success(let code):
            return code
        default:
            return -1
        }
    }

    var body: some View {
        TestComponentView(
            testResult: $testReport.result,
            readyForTest: $readyToTest,
            testName: "Perform Network Call Test",
            testAction: {
                readyToTest = false
                testReport.result = .testing
                spanExporter.clearAll()
            })
        .onChange(of: spanExporter.state) { _, newValue in
            switch newValue {
            case .clear:
                if testReport.result == .testing {
                    Task {
                        await client.makeTestNetworkCall(to: testURL)
                    }
                } else {
                    readyToTest = true
                }
            case .ready:
                if testReport.result == .testing {
                    testReport = spanExporter.performTest(NetworkingTest(testURL: testURL, statusCode: statusCode))
                    reportPresented.toggle()
                } else {
                    readyToTest = true
                }
            case .testing, .waiting:
                readyToTest = false
            }
        }
        .onAppear() {
            readyToTest = spanExporter.state != .waiting
        }
        .sheet(isPresented: $reportPresented) {
            TestReportCard(report: $testReport)
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    NetworkingTestUIComponent()
        .environmentObject(spanExporter)
}
