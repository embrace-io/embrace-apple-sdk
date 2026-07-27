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

    // MARK: - Bounds sanity

    func test_bounds_areOrdered() {
        XCTAssertLessThan(HangLimits.minSampleTriggerThreshold, HangLimits.maxSampleTriggerThreshold)
        XCTAssertLessThan(HangLimits.minSamplePollInterval, HangLimits.maxSamplePollInterval)
    }
}
