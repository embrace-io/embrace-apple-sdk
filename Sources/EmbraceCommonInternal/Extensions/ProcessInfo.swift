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
        let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, 
            appropriateFor: nil,
            create: false
        )

        return directory?.absoluteString.contains("XCTestDevices") == true
    }
}
