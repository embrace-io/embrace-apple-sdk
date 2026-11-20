//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import XCTest

final class SmoothnessLimitsTests: XCTestCase {

    func test_init_hasCorrectDefaultValues() {
        let limits = SmoothnessLimits()
        XCTAssertEqual(limits.idleThreshold, 0.1)
        XCTAssertEqual(limits.heldIdleThreshold, 0.5)
        XCTAssertEqual(limits.spanLimit, 250)
    }

    func test_init_honoursValidValues() {
        let limits = SmoothnessLimits(idleThreshold: 0.2, heldIdleThreshold: 0.05, spanLimit: 1000)
        XCTAssertEqual(limits.idleThreshold, 0.2)
        // Held below idle is not enforced, matching Android.
        XCTAssertEqual(limits.heldIdleThreshold, 0.05)
        XCTAssertEqual(limits.spanLimit, 1000)
    }

    func test_init_honoursZeroSpanLimit() {
        XCTAssertEqual(SmoothnessLimits(spanLimit: 0).spanLimit, 0)
    }

    func test_init_nonPositiveThresholds_fallBackToDefaults() {
        let zero = SmoothnessLimits(idleThreshold: 0, heldIdleThreshold: 0)
        XCTAssertEqual(zero.idleThreshold, SmoothnessLimits.defaultIdleThreshold)
        XCTAssertEqual(zero.heldIdleThreshold, SmoothnessLimits.defaultHeldIdleThreshold)

        let negative = SmoothnessLimits(idleThreshold: -0.1, heldIdleThreshold: -0.5)
        XCTAssertEqual(negative.idleThreshold, SmoothnessLimits.defaultIdleThreshold)
        XCTAssertEqual(negative.heldIdleThreshold, SmoothnessLimits.defaultHeldIdleThreshold)
    }

    func test_init_nonFiniteThresholds_fallBackToDefaults() {
        let limits = SmoothnessLimits(idleThreshold: .infinity, heldIdleThreshold: .nan)
        XCTAssertEqual(limits.idleThreshold, SmoothnessLimits.defaultIdleThreshold)
        XCTAssertEqual(limits.heldIdleThreshold, SmoothnessLimits.defaultHeldIdleThreshold)
    }

    func test_init_negativeSpanLimit_fallsBackToDefault() {
        XCTAssertEqual(SmoothnessLimits(spanLimit: -1).spanLimit, SmoothnessLimits.defaultSpanLimit)
    }
}
