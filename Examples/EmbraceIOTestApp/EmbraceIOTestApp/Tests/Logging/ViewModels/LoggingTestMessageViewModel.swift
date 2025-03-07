//
//  LoggingTestErrorMessageViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

class LoggingTestMessageViewModel: LogTestUIComponentViewModel {
    @Published var message: String = "A custom log" {
        didSet {
            testObject.loggedMessage = message
        }
    }

    @Published var logSeverity: LogSeverity = .info {
        didSet {
            testObject.loggedMessageSeverity = logSeverity
        }
    }

    var logSeverities: [LogSeverity] {
        LogSeverity.allCases
    }

    private var testObject = LoggingErrorMessageTest("", severity: .info)

    init(dataModel: any TestScreenDataModel) {
        super.init(dataModel: dataModel, payloadTestObject: self.testObject)
        self.message = message
    }
}

extension LogSeverity: @retroactive CaseIterable {
    public static var allCases: [LogSeverity] {
        [.trace, .debug, .info, .warn, .error, .fatal]
    }
}
