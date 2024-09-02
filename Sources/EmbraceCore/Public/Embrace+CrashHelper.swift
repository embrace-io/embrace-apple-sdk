//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Embrace {
    /// This defines the error types related to crash reporting within the Embrace SDK.
    private enum EmbraceCrashReportError: LocalizedError, CustomNSError {
        case noCrashReporterAvailable

        var errorDescription: String? {
            switch self {
            case .noCrashReporterAvailable:
                return "No crash reporter is available to append information."
            }
        }

        static var errorDomain: String {
            return "Embrace"
        }

        var errorCode: Int {
            switch self {
            case .noCrashReporterAvailable:
                return 1000
            }
        }

        var errorUserInfo: [String: Any] {
            switch self {
            case .noCrashReporterAvailable:
                return [NSLocalizedDescriptionKey: self.errorDescription ?? ""]
            }
        }
    }

    /// Crash the app in the prescribed manner.
    /// This method is used to test the Embrace Crash Reporter.
    ///
    /// The Xcode debugger will prevent the EmbraceCrashReporter from properly handling crashes,
    /// when validating that crashes appear in the Embrace dashboard, be sure to run without the Xcode
    /// debugger connected (without 'Debug executable' checked in Edit Scheme -> Run settings).
    ///
    /// - Note: Do not use in production
    public func crash(type: ExampleCrash = .fatalError) -> Never {
        CrashHelper.crash(example: type)
    }
    
    /// Appends additional key-value information to the next crash report.
    ///
    /// This method allows the addition of a key-value pair as an attribute to the next occurring
    /// crash that is reported during the lifetime of the process. This can be useful for adding context
    /// or debugging information that may help in analyzing the crash when exported.
    ///
    /// - Important: Throws an exception if no `CrashReporter` is configured.
    ///
    /// - Parameters:
    ///   - key: The key for the attribute.
    ///   - value: The value associated with the given key.
    @objc public func appendCrashInfo(key: String, value: String) throws {
        guard let crashRporter = captureServices.crashReporter else {
            throw EmbraceCrashReportError.noCrashReporterAvailable
        }
    }
}
