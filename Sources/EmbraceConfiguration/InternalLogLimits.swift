//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// InternalLogLimits manages limits for the logs the SDK produces about its own operation
/// This is broken into the major log severities so each can be managed
public struct InternalLogLimits: Equatable {
    public let trace: UInt
    public let debug: UInt
    public let info: UInt
    public let warning: UInt
    public let error: UInt

    public init(trace: UInt = 0, debug: UInt = 0, info: UInt = 0, warning: UInt = 0, error: UInt = 3) {
        self.trace = trace
        self.debug = debug
        self.info = info
        self.warning = warning
        self.error = error
    }

    public static func == (lhs: InternalLogLimits, rhs: InternalLogLimits) -> Bool {
        return lhs.trace == rhs.trace && lhs.debug == rhs.debug && lhs.info == rhs.info && lhs.warning == rhs.warning && lhs.error == rhs.error
    }
}
