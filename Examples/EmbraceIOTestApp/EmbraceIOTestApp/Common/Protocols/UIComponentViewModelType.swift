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
    var payloadTestObject: any PayloadTest { get }
    func testButtonPressed()
    func testFinished(with report: TestReport)
}

