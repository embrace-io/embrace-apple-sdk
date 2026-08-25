//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import XCTest

final class ExperimentsLimitsTests: XCTestCase {

    // MARK: - Defaults

    func test_init_hasCorrectDefaultValues() {
        let limits = ExperimentsLimits()
        XCTAssertEqual(limits.maxCount, 500)
        XCTAssertEqual(limits.maxIdLength, 128)
        XCTAssertEqual(limits.maxVariantLength, 128)

        XCTAssertEqual(limits.maxCount, ExperimentsLimits.defaultMaxCount)
        XCTAssertEqual(limits.maxIdLength, ExperimentsLimits.defaultMaxIdLength)
        XCTAssertEqual(limits.maxVariantLength, ExperimentsLimits.defaultMaxVariantLength)
    }

    // MARK: - Remote values within range

    func test_init_honoursValuesBelowTheDefaults() {
        let limits = ExperimentsLimits(maxCount: 10, maxIdLength: 16, maxVariantLength: 32)
        XCTAssertEqual(limits.maxCount, 10)
        XCTAssertEqual(limits.maxIdLength, 16)
        XCTAssertEqual(limits.maxVariantLength, 32)
    }

    func test_init_honoursValuesAboveTheDefaultsButBelowTheCeilings() {
        // A remote config may raise a limit; only the ceiling binds it.
        let limits = ExperimentsLimits(maxCount: 2000, maxIdLength: 512, maxVariantLength: 512)
        XCTAssertEqual(limits.maxCount, 2000)
        XCTAssertEqual(limits.maxIdLength, 512)
        XCTAssertEqual(limits.maxVariantLength, 512)
    }

    func test_init_honoursZero() {
        // Zero is a valid way to turn tracking off, not a malformed value.
        let limits = ExperimentsLimits(maxCount: 0, maxIdLength: 0, maxVariantLength: 0)
        XCTAssertEqual(limits.maxCount, 0)
        XCTAssertEqual(limits.maxIdLength, 0)
        XCTAssertEqual(limits.maxVariantLength, 0)
    }

    // MARK: - Clamping at the ceilings

    func test_init_clampsMaxCountToCeiling() {
        let limits = ExperimentsLimits(maxCount: 6000)
        XCTAssertEqual(limits.maxCount, 5000)
        XCTAssertEqual(limits.maxCount, ExperimentsLimits.maxSettableCount)
    }

    func test_init_clampsLengthsToCeilings() {
        let limits = ExperimentsLimits(maxIdLength: 2048, maxVariantLength: 2048)
        XCTAssertEqual(limits.maxIdLength, 1024)
        XCTAssertEqual(limits.maxVariantLength, 1024)
        XCTAssertEqual(limits.maxIdLength, ExperimentsLimits.maxSettableIdLength)
        XCTAssertEqual(limits.maxVariantLength, ExperimentsLimits.maxSettableVariantLength)
    }

    func test_init_honoursValuesExactlyAtTheCeilings() {
        let limits = ExperimentsLimits(
            maxCount: ExperimentsLimits.maxSettableCount,
            maxIdLength: ExperimentsLimits.maxSettableIdLength,
            maxVariantLength: ExperimentsLimits.maxSettableVariantLength
        )
        XCTAssertEqual(limits.maxCount, ExperimentsLimits.maxSettableCount)
        XCTAssertEqual(limits.maxIdLength, ExperimentsLimits.maxSettableIdLength)
        XCTAssertEqual(limits.maxVariantLength, ExperimentsLimits.maxSettableVariantLength)
    }

    // MARK: - Negative values fall back to the defaults

    func test_init_fallsBackToDefaultForNegativeMaxCount() {
        // A negative value is malformed rather than a smaller limit, so it must not disable tracking.
        XCTAssertEqual(ExperimentsLimits(maxCount: -1).maxCount, ExperimentsLimits.defaultMaxCount)
    }

    func test_init_fallsBackToDefaultForNegativeMaxIdLength() {
        XCTAssertEqual(ExperimentsLimits(maxIdLength: -1).maxIdLength, ExperimentsLimits.defaultMaxIdLength)
    }

    func test_init_fallsBackToDefaultForNegativeMaxVariantLength() {
        XCTAssertEqual(
            ExperimentsLimits(maxVariantLength: -1).maxVariantLength,
            ExperimentsLimits.defaultMaxVariantLength
        )
    }

    func test_init_fallsBackToDefaultsForAllNegativeValues() {
        let limits = ExperimentsLimits(maxCount: -100, maxIdLength: -100, maxVariantLength: -100)
        XCTAssertEqual(limits, ExperimentsLimits())
    }

    // MARK: - Equality / hashing (NSObject contract)

    func test_isEqual_isTrueWhenLimitsMatch() {
        let limits1 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        let limits2 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        XCTAssertEqual(limits1, limits2)
    }

    func test_isEqual_isFalseWhenMaxCountDiffers() {
        let limits1 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        let limits2 = ExperimentsLimits(maxCount: 101, maxIdLength: 20, maxVariantLength: 30)
        XCTAssertNotEqual(limits1, limits2)
    }

    func test_isEqual_isFalseWhenMaxIdLengthDiffers() {
        let limits1 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        let limits2 = ExperimentsLimits(maxCount: 100, maxIdLength: 21, maxVariantLength: 30)
        XCTAssertNotEqual(limits1, limits2)
    }

    func test_isEqual_isFalseWhenMaxVariantLengthDiffers() {
        let limits1 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        let limits2 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 31)
        XCTAssertNotEqual(limits1, limits2)
    }

    func test_isEqual_isFalseWhenDifferentTypes() {
        let limits = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        XCTAssertFalse(limits.isEqual("ExperimentsLimits"))
    }

    func test_equalInstances_shareHash() {
        let limits1 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        let limits2 = ExperimentsLimits(maxCount: 100, maxIdLength: 20, maxVariantLength: 30)
        XCTAssertEqual(
            limits1.hash, limits2.hash, "equal ExperimentsLimits must return the same hash (NSObject contract)")
        XCTAssertEqual(Set([limits1, limits2]).count, 1, "equal instances should dedupe in a Set")
    }

    // MARK: - Bounds sanity

    func test_ceilings_areNotBelowTheDefaults() {
        XCTAssertGreaterThanOrEqual(ExperimentsLimits.maxSettableCount, ExperimentsLimits.defaultMaxCount)
        XCTAssertGreaterThanOrEqual(ExperimentsLimits.maxSettableIdLength, ExperimentsLimits.defaultMaxIdLength)
        XCTAssertGreaterThanOrEqual(
            ExperimentsLimits.maxSettableVariantLength, ExperimentsLimits.defaultMaxVariantLength)
    }
}
