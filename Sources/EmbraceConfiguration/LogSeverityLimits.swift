//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// `LogSeverityLimits` manages limits for the logs generated through the SDK.
/// This is broken into the major log severities so each can be managed.
public struct LogSeverityLimits: Equatable {

    public let info: UInt
    /// Includes trace, debug and info logs
    public let warn: UInt
    public let error: UInt
    /// Includes error and critical logs

    public init(info: UInt = 100, warn: UInt = 200, error: UInt = 500) {
        self.info = info
        self.warn = warn
        self.error = error
    }

    public static func == (lhs: LogSeverityLimits, rhs: LogSeverityLimits) -> Bool {
        return lhs.info == rhs.info && lhs.warn == rhs.warn && lhs.error == rhs.error
    }
}
