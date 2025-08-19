//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension ProcessInfo {
    public var isTesting: Bool {
        // detect if the process is running unit tests
        guard processName != "xctest" else {
            return true
        }

        // detect if the process is running ui tests
        guard CommandLine.arguments.isEmpty == false else {
            return false
        }

        return CommandLine.arguments[0].contains("XCTestDevices") == true
    }
}
