//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
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

/// Sometimes a test just can't run more than once for N reasons, this helps skip it
/// if run more than once without failing.
private let _runCountMap: EmbraceMutex<[String: Int]> = EmbraceMutex([:])
extension XCTestCase {
    public func XCTSkipIfRunMoreThanOnce(_ function: String = #function) throws {
        let count = _runCountMap.withLock {
            let val = $0[function, default: 0]
            $0[function] = val + 1
            return val
        }
        guard count < 1 else {
            throw XCTSkip("Skipping test as it ran more than once")
        }
    }
}
