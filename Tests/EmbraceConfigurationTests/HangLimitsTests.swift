//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import XCTest

final class HangLimitsTests: XCTestCase {

    func test_init_hasCorrectDefaultValues() {
        let limits = HangLimits()
        XCTAssertEqual(limits.hangThreshold, HangLimits.defaultHangThreshold)
        XCTAssertEqual(limits.hangPerSession, HangLimits.defaultHangPerSession)
        XCTAssertEqual(limits.reportsWatchdogEvents, HangLimits.defaultReportsWatchdogEvents)
        XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.defaultSampleTriggerThreshold)
        XCTAssertEqual(limits.samplePollInterval, HangLimits.defaultSamplePollInterval)
    }

    // MARK: - Sampler value clamping (the trap-prevention fix)

    func test_init_clampsSampleValuesUpToMinimum() {
        let limits = HangLimits(sampleTriggerThreshold: 0.0001, samplePollInterval: 0.0001)
        XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.minSampleTriggerThreshold)
        XCTAssertEqual(limits.samplePollInterval, HangLimits.minSamplePollInterval)
    }

    func test_init_clampsSampleValuesDownToMaximum() {
        // A seconds/ms mixup like 5000 would previously overflow the sampler's `useconds_t`/`UInt64`
        // conversion and trap the process; the upper clamp is what prevents that.
        let limits = HangLimits(sampleTriggerThreshold: 5000, samplePollInterval: 5000)
        XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.maxSampleTriggerThreshold)
        XCTAssertEqual(limits.samplePollInterval, HangLimits.maxSamplePollInterval)
    }

    func test_init_fallsBackToDefaultForNonFiniteSampleValues() {
        for bad in [Double.nan, .infinity, -.infinity] {
            let limits = HangLimits(sampleTriggerThreshold: bad, samplePollInterval: bad)
            XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.defaultSampleTriggerThreshold)
            XCTAssertEqual(limits.samplePollInterval, HangLimits.defaultSamplePollInterval)
        }
    }

    func test_init_preservesInRangeSampleValues() {
        let limits = HangLimits(sampleTriggerThreshold: 0.2, samplePollInterval: 0.03)
        XCTAssertEqual(limits.sampleTriggerThreshold, 0.2, accuracy: 1e-9)
        XCTAssertEqual(limits.samplePollInterval, 0.03, accuracy: 1e-9)
    }

    // MARK: - hangThreshold sanitization

    func test_init_sanitizesNonPositiveOrNonFiniteHangThreshold() {
        for bad in [0, -1, Double.nan, .infinity] {
            let limits = HangLimits(hangThreshold: bad)
            XCTAssertEqual(limits.hangThreshold, HangLimits.defaultHangThreshold)
        }
    }

    func test_init_preservesValidHangThreshold() {
        XCTAssertEqual(HangLimits(hangThreshold: 0.5).hangThreshold, 0.5, accuracy: 1e-9)
    }

    // MARK: - Equality / hashing (NSObject contract)

    func test_equalInstances_shareHashAndAreEqual() {
        let a = HangLimits(hangThreshold: 0.3, hangPerSession: 5, samplePollInterval: 0.02)
        let b = HangLimits(hangThreshold: 0.3, hangPerSession: 5, samplePollInterval: 0.02)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hash, b.hash, "equal HangLimits must return the same hash (NSObject contract)")
        XCTAssertEqual(Set([a, b]).count, 1, "equal instances should dedupe in a Set")
    }

    func test_differingInstances_areNotEqual() {
        let a = HangLimits(hangThreshold: 0.3)
        let b = HangLimits(hangThreshold: 0.4)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Bounds sanity

    func test_bounds_areOrdered() {
        XCTAssertLessThan(HangLimits.minSampleTriggerThreshold, HangLimits.maxSampleTriggerThreshold)
        XCTAssertLessThan(HangLimits.minSamplePollInterval, HangLimits.maxSamplePollInterval)
    }
}
