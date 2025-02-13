//
//  UIComponentViewModelType.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

protocol UIComponentViewModelType: ObservableObject {
    var testResult: TestResult { get }
    var testReport: TestReport { get }
    var readyToTest: Bool { get set }
    var state: TestViewModelState { get set }
    var dataModel: any TestScreenDataModel { get }
    func testButtonPressed(_ clearBeforeBegin: Bool)
    func testFinished(with report: TestReport)
}

extension UIComponentViewModelType {
    func testButtonPressed(_ clearBeforeBegin: Bool = true) {
        testButtonPressed(clearBeforeBegin)
    }
}
