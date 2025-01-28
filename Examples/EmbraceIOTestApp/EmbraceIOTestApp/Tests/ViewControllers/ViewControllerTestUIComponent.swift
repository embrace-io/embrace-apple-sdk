//
//  ViewControllerTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct ViewControllerTestUIComponent: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    @State private var testReport: TestReport = .init(result: .unknown, testItems: [])
    @State private var readyToTest: Bool = false
    @State private var viewDidLoadSimulated: Bool = false
    @State private var reportPresented: Bool = false
    var body: some View {
        TestComponentView(
            testResult: .constant(testReport.result),
            readyForTest: $readyToTest,
            testName: "Perform ViewController Test",
            testAction: {
                readyToTest = false
                testReport.result = .testing
                spanExporter.clearAll()
            })
        .onChange(of: spanExporter.state) { _, newValue in
            switch newValue {
            case .clear:
                if testReport.result == .testing {
                    let a = TestViewController()
                    a.viewDidLoad()
                } else {
                    readyToTest = true
                }
            case .ready:
                if testReport.result == .testing {
                    testReport = spanExporter.performTest(ViewControllerViewDidLoadTest())
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
