//
//  UIComponentViewModelBase.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

@Observable class UIComponentViewModelBase: NSObject, UIComponentViewModelType {
    private(set) var testReport: TestReport = .init(items: [])
    var readyToTest: Bool = false
    var presentReport: Bool = false
    var testResult: TestResult = .unknown
    var dataModel: any TestScreenDataModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
    }

    func updateTestReport(with report: TestReport) {
        self.testReport = report
        self.presentReport.toggle()
    }

    func testButtonPressed() {
        print("testButtonPressed() must be overridden in viewModel subclass")
    }
}
