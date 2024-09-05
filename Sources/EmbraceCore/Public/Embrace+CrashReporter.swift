//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

@objc
extension Embrace {
    /// This defines the error types related to crash reporting within the Embrace SDK.
    private enum EmbraceCrashReportError: LocalizedError, CustomNSError {
        case noCrashReporterAvailable
        case crashReporterIsNotExtendable

        var errorDescription: String? {
            switch self {
            case .noCrashReporterAvailable:
                return "No crash reporter is available to append information."
            case .crashReporterIsNotExtendable:
                return "Cannot add extra information to the given crash reporter"
            }
        }

        static var errorDomain: String {
            return "Embrace"
        }

        var errorCode: Int {
            switch self {
            case .noCrashReporterAvailable:
                return 1000
            case .crashReporterIsNotExtendable:
                return 1001
            }
        }

        var errorUserInfo: [String: Any] {
            return [NSLocalizedDescriptionKey: self.errorDescription ?? ""]
        }
    }

    /// Appends additional key-value information to the next crash report.
    ///
    /// This method allows the addition of a key-value pair as an attribute to the next occurring
    /// crash that is reported during the lifetime of the process. This can be useful for adding context
    /// or debugging information that may help in analyzing the crash when exported.
    ///
    /// - Important: Throws an exception if no proper `CrashReporter` is configured.
    ///
    /// - Parameters:
    ///   - key: The key for the attribute.
    ///   - value: The value associated with the given key.
    public func appendCrashInfo(key: String, value: String) throws {
        guard let crashRporter = captureServices.crashReporter else {
            throw EmbraceCrashReportError.noCrashReporterAvailable
        }

        guard let extendableCrashReporter = crashRporter as? ExtendableCrashReporter else {
            throw EmbraceCrashReportError.noCrashReporterAvailable
        }

        extendableCrashReporter.appendCrashInfo(key: key, value: value)
    }

    /// Returns the last run end state.
    public func lastRunEndState() -> LastRunEndState {
        guard let crashReporterEndState = captureServices.crashReporter?.getLastRunState() else {
            return .unavailable
        }

        return LastRunEndState(rawValue: crashReporterEndState.rawValue) ?? .unavailable
    }

}
