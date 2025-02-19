//
//  LoggingTestErrorMessageViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class LoggingTestErrorMessageViewModel: LogTestUIComponentViewModel {
    @Published var message: String = "A custom log" {
        didSet {
            testObject.loggedMessage = message
        }
    }
    private var testObject = LoggingErrorMessageTest("")

    init(dataModel: any TestScreenDataModel) {
        super.init(dataModel: dataModel, payloadTestObject: self.testObject)
        self.message = message
    }
}
