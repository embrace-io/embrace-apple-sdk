//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceConfiguration

final class HangLimitsTests: XCTestCase {

    func test_init_hasCorrectDefaultValues() {
        let limits = HangLimits()
        XCTAssertEqual(limits.hangThreshold, HangLimits.defaultHangThreshold)
        XCTAssertEqual(limits.hangPerSession, HangLimits.defaultHangPerSession)
        XCTAssertEqual(limits.reportsWatchdogEvents, HangLimits.defaultReportsWatchdogEvents)
        // The default trigger (0.15) exceeds the cap (60% of the default hangThreshold), so it lands
        // exactly at the cap.
        XCTAssertEqual(
            limits.sampleTriggerThreshold,
            HangLimits.defaultHangThreshold * HangLimits.sampleTriggerFraction, accuracy: 1e-9)
        XCTAssertEqual(limits.samplePollInterval, HangLimits.defaultSamplePollInterval)
    }

    // MARK: - Sampler value clamping (the trap-prevention fix)

    func test_init_clampsSampleValuesUpToMinimum() {
        let limits = HangLimits(sampleTriggerThreshold: 0.0001, samplePollInterval: 0.0001)
        XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.minSampleTriggerThreshold)
        XCTAssertEqual(limits.samplePollInterval, HangLimits.minSamplePollInterval)
    }

    func test_init_clampsSamplePollIntervalDownToMaximum() {
        // A seconds/ms mixup like 5000 would previously overflow the sampler's `UInt64` ns conversion
        // and trap the process; the upper clamp is what prevents that.
        XCTAssertEqual(
            HangLimits(samplePollInterval: 5000).samplePollInterval, HangLimits.maxSamplePollInterval)
    }

    func test_init_clampsSampleTriggerDownToMaximum() {
        // hangThreshold large enough that 60% of it exceeds the absolute max, so the max is the binding cap.
        let limits = HangLimits(hangThreshold: 10000, sampleTriggerThreshold: 5000)
        XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.maxSampleTriggerThreshold)
    }

    func test_init_fallsBackToDefaultForNonFiniteSampleValues() {
        // hangThreshold high enough that the default trigger isn't capped, isolating the fallback.
        for bad in [Double.nan, .infinity, -.infinity] {
            let limits = HangLimits(hangThreshold: 1.0, sampleTriggerThreshold: bad, samplePollInterval: bad)
            XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.defaultSampleTriggerThreshold)
            XCTAssertEqual(limits.samplePollInterval, HangLimits.defaultSamplePollInterval)
        }
    }

    // MARK: - Trigger capped at a fraction of hangThreshold

    func test_init_preservesSampleTriggerBelowCap() {
        // A trigger below the cap (0.6 × 0.249 ≈ 0.149) is used as-is; poll in range is preserved.
        let limits = HangLimits(hangThreshold: 0.249, sampleTriggerThreshold: 0.12, samplePollInterval: 0.03)
        XCTAssertEqual(limits.sampleTriggerThreshold, 0.12, accuracy: 1e-9)
        XCTAssertEqual(limits.samplePollInterval, 0.03, accuracy: 1e-9)
    }

    func test_init_capsSampleTriggerAtFractionOfHangThreshold() {
        // 0.15 exceeds 60% of hangThreshold → capped to exactly that fraction (still below hangThreshold).
        let limits = HangLimits(hangThreshold: 0.249, sampleTriggerThreshold: 0.15)
        XCTAssertLessThan(limits.sampleTriggerThreshold, limits.hangThreshold)
        XCTAssertEqual(
            limits.sampleTriggerThreshold,
            limits.hangThreshold * HangLimits.sampleTriggerFraction, accuracy: 1e-9)
    }

    func test_init_capsSampleTriggerWhenRequestedAtOrAboveHangThreshold() {
        // Even a trigger >= hangThreshold caps to the fraction, not just an out-of-range value.
        let limits = HangLimits(hangThreshold: 0.1, sampleTriggerThreshold: 0.15)
        XCTAssertLessThan(limits.sampleTriggerThreshold, limits.hangThreshold)
        XCTAssertEqual(
            limits.sampleTriggerThreshold,
            limits.hangThreshold * HangLimits.sampleTriggerFraction, accuracy: 1e-9)
    }

    func test_init_orderingKeepsDerivedTriggerBounded_forHugeHangThreshold() {
        // A huge hangThreshold must not leak into the trigger's ns conversion (overflow guard).
        let limits = HangLimits(hangThreshold: 1e12, sampleTriggerThreshold: 5000)
        XCTAssertLessThanOrEqual(limits.sampleTriggerThreshold, HangLimits.maxSampleTriggerThreshold)
        XCTAssertLessThan(limits.sampleTriggerThreshold, limits.hangThreshold)
    }

    func test_init_floorWinsOverCapForSmallHangThreshold() {
        // hangThreshold below minSampleTriggerThreshold / sampleTriggerFraction (≈ 0.083): 60% of it
        // (≈ 0.036) is below the floor, so the floor takes precedence over the cap. Guards the
        // `max(…, minSampleTriggerThreshold)` in the ceiling — without it the trigger would dip below
        // the floor. (For an even smaller hangThreshold ≤ the floor the below-hangThreshold guarantee is
        // intentionally sacrificed; that's a degenerate config, documented on `sampleTriggerThreshold`.)
        let limits = HangLimits(hangThreshold: 0.06, sampleTriggerThreshold: 0.05)
        XCTAssertEqual(limits.sampleTriggerThreshold, HangLimits.minSampleTriggerThreshold, accuracy: 1e-9)
    }

    // MARK: - hangThreshold sanitization

    func test_init_sanitizesNonPositiveOrNonFiniteHangThreshold() {
        for bad in [0, -1, Double.nan, .infinity, -.infinity] {
            let limits = HangLimits(hangThreshold: bad)
            XCTAssertEqual(limits.hangThreshold, HangLimits.defaultHangThreshold)
        }
    }

    func test_init_preservesValidHangThreshold() {
        XCTAssertEqual(HangLimits(hangThreshold: 0.5).hangThreshold, 0.5, accuracy: 1e-9)
    }

    // MARK: - Equality

    // `HangLimits` is a struct with synthesized `Equatable`, so equality covers every stored
    // property — including the clamped sampler values, which is what these assert.
    func test_equalInstances_areEqual() {
        let a = HangLimits(hangThreshold: 0.3, hangPerSession: 5, samplePollInterval: 0.02)
        let b = HangLimits(hangThreshold: 0.3, hangPerSession: 5, samplePollInterval: 0.02)
        XCTAssertEqual(a, b)
    }

    func test_instancesDifferingOnlyBySamplerValues_areNotEqual() {
        let a = HangLimits(sampleTriggerThreshold: 0.1, samplePollInterval: 0.02)
        let b = HangLimits(sampleTriggerThreshold: 0.12, samplePollInterval: 0.03)
        XCTAssertNotEqual(a, b)
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

    func test_sampleTriggerFraction_isBelowOne() {
        // The cap `hangThreshold * sampleTriggerFraction` only stays below hangThreshold while the
        // fraction is < 1. Pin it so that invariant can't silently break.
        XCTAssertGreaterThan(HangLimits.sampleTriggerFraction, 0)
        XCTAssertLessThan(HangLimits.sampleTriggerFraction, 1)
    }
}
