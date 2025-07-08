//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// LogsLimits manages limits for the logs generated through the SDK
/// This is broken into the major log severities so each can be managed
@objc public class LogsLimits: NSObject {
    public let info: UInt /// Includes trace, debug and info logs
    public let warning: UInt
    public let error: UInt /// Includes error and critical logs

    public init(info: UInt = 100, warning: UInt = 200, error: UInt = 500) {
        self.info = info
        self.warning = warning
        self.error = error
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Self else {
            return false
        }

        return
            info == other.info &&
            warning == other.warning &&
            error == other.error
    }
}
