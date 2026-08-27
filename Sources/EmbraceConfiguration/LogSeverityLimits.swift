//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// `LogSeverityLimits` manages limits for the logs generated through the SDK.
/// This is broken into the major log severities so each can be managed.
public struct LogSeverityLimits: Equatable {

    /// Maximum number of info-level logs. Includes trace, debug and info logs.
    public let info: UInt

    /// Maximum number of warn-level logs.
    public let warn: UInt

    /// Maximum number of error-level logs. Includes error and critical logs.
    public let error: UInt

    /// Creates a new `LogSeverityLimits` with the given per-severity limits.
    public init(info: UInt = 100, warn: UInt = 200, error: UInt = 500) {
        self.info = info
        self.warn = warn
        self.error = error
    }

    public static func == (lhs: LogSeverityLimits, rhs: LogSeverityLimits) -> Bool {
        return lhs.info == rhs.info && lhs.warn == rhs.warn && lhs.error == rhs.error
    }
}
