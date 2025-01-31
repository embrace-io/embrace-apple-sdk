//
//  ViewControllerTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct ViewControllerTestUIComponent: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State private var testResult: TestResult = .unknown
    @State private var testReport = TestReport(items: [])
    @State private var readyToTest: Bool = false
    @State private var viewDidLoadSimulated: Bool = false
    @State private var reportPresented: Bool = false
    var body: some View {
        TestComponentView(
            testResult: $testResult,
            readyForTest: $readyToTest,
            testName: "Perform ViewController Test",
            testAction: {
                readyToTest = false
                testResult = .testing
                spanExporter.clearAll()
            })
        .onChange(of: spanExporter.state) { _, newValue in
            switch newValue {
            case .clear:
                if testResult == .testing {
                    let a = TestViewController()
                    a.viewDidLoad()
                } else {
                    readyToTest = true
                }
            case .ready:
                if testResult == .testing {
                    testReport = spanExporter.performTest(ViewControllerViewDidLoadTest())
                    testResult = testReport.result
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

private class TestViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        print("TestViewDidLoad Called")
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    ViewControllerTestUIComponent()
        .environmentObject(spanExporter)
}
