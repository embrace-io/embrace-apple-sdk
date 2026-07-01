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
    /// Skips the test when it runs under ThreadSanitizer or AddressSanitizer.
    ///
    /// Xcode injects `TSAN_OPTIONS` / `ASAN_OPTIONS` into the test process when the
    /// corresponding sanitizer is enabled, so their presence is a reliable signal.
    ///
    /// Use this for tests that are fundamentally incompatible with sanitizer runs:
    /// - Performance tests (`measure(...)`): the instrumentation dominates timing and
    ///   I/O, so the numbers are meaningless, and some `XCTMetric` teardown paths crash
    ///   (e.g. `XCTStorageMetric` BUS-faults in `objc_release` under TSan).
    /// - Code paths the sanitizers can't handle, such as KSCrash's binary-image cache
    ///   (TSan aborts; ASan deadlocks until the job timeout fires).
    public func XCTSkipIfSanitizing(_ message: String? = nil) throws {
        let env = ProcessInfo.processInfo.environment
        guard env["TSAN_OPTIONS"] == nil, env["ASAN_OPTIONS"] == nil else {
            throw XCTSkip(message ?? "Skipping test under sanitizer instrumentation")
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
private var _runCountMap: EmbraceMutex<[String: Int]> = EmbraceMutex([:])
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
