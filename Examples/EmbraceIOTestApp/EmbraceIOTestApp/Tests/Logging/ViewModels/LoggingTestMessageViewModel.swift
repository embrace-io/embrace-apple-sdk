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

    @Published var stacktraceBehavior: StackTraceBehavior = .default {
        didSet {
            testObject.stackTraceBehavior = stacktraceBehavior
        }
    }

    var logSeverities: [LogSeverity] {
        LogSeverity.allCases
    }

    var stacktraceBehaviors: [StackTraceBehavior] {
        StackTraceBehavior.allCases
    }

    private var testObject = LoggingErrorMessageTest("", severity: .info)

    init(dataModel: any TestScreenDataModel) {
        super.init(dataModel: dataModel, payloadTestObject: self.testObject)
        self.message = message
    }

    func addLogAttribute(key: String, value: String) {
        testObject.logProperties[key.replacingOccurrences(of: " ", with: "")] = value
    }
}

extension LogSeverity: @retroactive CaseIterable {
    public static var allCases: [LogSeverity] {
        [.trace, .debug, .info, .warn, .error, .fatal]
    }
}

extension StackTraceBehavior: @retroactive CaseIterable {
    public static var allCases: [StackTraceBehavior] {
        [.default, .notIncluded]
    }

    var text: String {
        switch self {
        case .default:
            "Default"
        case .notIncluded:
            "Not Included"
        }
    }
}
