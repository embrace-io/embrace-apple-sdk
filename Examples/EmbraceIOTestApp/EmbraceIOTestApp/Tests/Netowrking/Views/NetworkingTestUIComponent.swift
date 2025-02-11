//
//  NetworkingTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct NetworkingTestUIComponent: View {
    @Environment(TestSpanExporter.self) private var spanExporter
    @State private var testResult: TestResult = .unknown
    @State private var testReport = TestReport(items: [])
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
        VStack {}
//        TestComponentView(
//            testResult: $testResult,
//            readyForTest: $readyToTest,
//            testName: "Perform Network Call Test",
//            testAction: {
//                readyToTest = false
//                testResult = .testing
//                spanExporter.clearAll()
//            })
//        .onChange(of: spanExporter.state) { _, newValue in
//            switch newValue {
//            case .clear:
//                if testResult == .testing {
//                    Task {
//                        await client.makeTestNetworkCall(to: testURL)
//                    }
//                } else {
//                    readyToTest = true
//                }
//            case .ready:
//                if testResult == .testing {
//                    testReport = spanExporter.performTest(NetworkingTest(testURL: testURL, statusCode: statusCode))
//                    reportPresented.toggle()
//                } else {
//                    readyToTest = true
//                }
//            case .testing, .waiting:
//                readyToTest = false
//            }
//        }
//        .onAppear() {
//            readyToTest = spanExporter.state != .waiting
//        }
//        .sheet(isPresented: $reportPresented) {
//            TestReportCard(report: $testReport)
//        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    NetworkingTestUIComponent()
        .environment(spanExporter)
}
