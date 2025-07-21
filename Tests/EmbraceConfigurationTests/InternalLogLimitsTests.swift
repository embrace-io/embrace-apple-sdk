//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import XCTest

final class InternalLogLimitsTests: XCTestCase {

    func test_init_hasCorrectDefaultValues() {
        let limits = InternalLogLimits()
        XCTAssertEqual(limits.trace, 0)
        XCTAssertEqual(limits.debug, 0)
        XCTAssertEqual(limits.info, 0)
        XCTAssertEqual(limits.warning, 0)
        XCTAssertEqual(limits.error, 3)
    }

    func test_init_withValues() {
        let limits = InternalLogLimits(
            trace: 1,
            debug: 2,
            info: 3,
            warning: 4,
            error: 5
        )
        XCTAssertEqual(limits.trace, 1)
        XCTAssertEqual(limits.debug, 2)
        XCTAssertEqual(limits.info, 3)
        XCTAssertEqual(limits.warning, 4)
        XCTAssertEqual(limits.error, 5)
    }

    func test_isEqual_isTrueWhenLimitsMatch() {
        let limits1 = InternalLogLimits(
            trace: 1,
            debug: 2,
            info: 3,
            warning: 4,
            error: 5
        )
        let limits2 = InternalLogLimits(
            trace: 1,
            debug: 2,
            info: 3,
            warning: 4,
            error: 5
        )
        XCTAssertEqual(limits1, limits2)
    }

    func test_isEqual_isFalseWhenLimitsDontMatch() {
        let limits1 = InternalLogLimits(
            trace: 1,
            debug: 2,
            info: 3,
            warning: 4,
            error: 5
        )
        let limits2 = InternalLogLimits(
            trace: 1,
            debug: 2,
            info: 3,
            warning: 4,
            error: 6
        )
        XCTAssertNotEqual(limits1, limits2)
    }

    func test_isEqual_isFalseWhenDifferentTypes() {
        let limits = InternalLogLimits(
            trace: 1,
            debug: 2,
            info: 3,
            warning: 4,
            error: 5
        )

        let result = limits.isEqual("InternalLogLimits")
        XCTAssertFalse(result)
    }

}
