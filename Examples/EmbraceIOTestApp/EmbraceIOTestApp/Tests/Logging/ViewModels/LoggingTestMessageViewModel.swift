//
//  LoggingTestErrorMessageViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

@Observable
class LoggingTestMessageViewModel: LogTestUIComponentViewModel {
    var message: String = "A custom log" {
        didSet {
            testObject.loggedMessage = message
        }
    }

    var logSeverity: LogSeverity = .info {
        didSet {
            testObject.loggedMessageSeverity = logSeverity
        }
    }

    var stacktraceBehavior: StackTraceBehavior = .default {
        didSet {
            testObject.stackTraceBehavior = stacktraceBehavior
        }
    }

    var includeAttachment: Bool = false {
        didSet {
            testObject.includeAttachment = includeAttachment
            if includeAttachment {
                testObject.attachmentSize = Int(attachmentSize)
            }
        }
    }
    /// This is a controlled test app. Make sure hardcoded file sizes are powers of 2.
    var attachmentSize: Float = 8192 {
        didSet {
            testObject.attachmentSize = Int(attachmentSize)
        }
    }

    var logSeverities: [LogSeverity] {
        LogSeverity.allCases
    }

    var stacktraceBehaviors: [StackTraceBehavior] {
        StackTraceBehavior.allCases
    }

    private var testObject: LoggingErrorMessageTest

    init(dataModel: any TestScreenDataModel) {
        let testObject = LoggingErrorMessageTest("", severity: .info)
        self.testObject = testObject
        super.init(dataModel: dataModel, payloadTestObject: testObject)
        self.message = message
    }

    func addLogAttribute(key: String, value: String) {
        testObject.logProperties[key.replacingOccurrences(of: " ", with: "")] = value
    }
}

extension LogSeverity: CaseIterable {
    public static var allCases: [LogSeverity] {
        [.trace, .debug, .info, .warn, .error, .fatal, .critical]
    }
}

extension StackTraceBehavior: CaseIterable {
    public static var allCases: [StackTraceBehavior] {
        [.default, .notIncluded, .custom(customStackTrace)]
    }

    var text: String {
        switch self {
        case .default:
            "Default"
        case .notIncluded:
            "Not Included"
        case .custom:
            "Custom"
        }
    }

    private static var customStackTrace: EmbraceStackTrace {
        do {
            let stackTrace = try EmbraceStackTrace(frames: [
                "0 EmbraceIOTestApp 0x0000000005678def [SomeClass method] + 48",
                "1 Random Library 0x0000000001234abc [Random init]"
            ])
            return stackTrace
        } catch {
            fatalError()
        }
    }
}

extension StackTraceBehavior: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .custom(let st):
            hasher.combine(st.frames)
        default:
            break
        }
    }
}
