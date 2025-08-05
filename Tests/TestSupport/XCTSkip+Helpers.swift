//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

extension XCTestCase {
    public func XCTSkipInCI(message: String? = "Skipping test in CI") throws {
        let envCI = ProcessInfo.processInfo.environment["CI"] ?? ""

        guard envCI.isEmpty else {
            throw XCTSkip(message)
        }
    }
}

extension XCTestCase {
    // this makes it easy to guard against watchOS without warnings
    public static func isWatchOS() -> Bool {
#if os(watchOS)
        return true
#else
        return false
#endif
    }
}
