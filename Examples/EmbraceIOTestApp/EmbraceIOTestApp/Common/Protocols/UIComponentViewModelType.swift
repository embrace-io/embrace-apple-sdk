//
//  UIComponentViewModelType.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

protocol UIComponentViewModelType: ObservableObject {
    var testResult: TestResult { get set }
    var testReport: TestReport { get }
    var readyToTest: Bool { get set }
    var presentReport: Bool { get set }
    var dataModel: any TestScreenDataModel { get }
    func testButtonPressed()
}
