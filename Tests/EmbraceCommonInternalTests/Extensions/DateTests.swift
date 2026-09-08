//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import XCTest

@testable import EmbraceCommonInternal

/// `Date` wraps a `Double`, so it accepts values that no integer timestamp can express. Those dates are
/// built without error and behave like ordinary dates until something converts them, at which point the
/// process dies. `isValid` is what keeps such a date from ever reaching a conversion, so these tests
/// pin down both what it rejects and that everything it accepts really is convertible.
final class DateTests: XCTestCase {

    /// Largest distance from the epoch that `Int64` nanoseconds can express, and therefore the widest
    /// date the SDK can convert. Duplicated from the implementation on purpose: a change to the bound
    /// should have to be made twice.
    private let maxInterval: TimeInterval = 9_223_372_036

    // MARK: - Rejected

    func test_isValid_nan_isFalse() {
        XCTAssertFalse(Date(timeIntervalSince1970: .nan).isValid)
        XCTAssertFalse(Date(timeIntervalSince1970: .signalingNaN).isValid)
    }

    func test_isValid_infinities_areFalse() {
        XCTAssertFalse(Date(timeIntervalSince1970: .infinity).isValid)
        XCTAssertFalse(Date(timeIntervalSince1970: -.infinity).isValid)
    }

    func test_isValid_hugeFiniteValues_areFalse() {
        XCTAssertFalse(Date(timeIntervalSince1970: .greatestFiniteMagnitude).isValid)
        XCTAssertFalse(Date(timeIntervalSince1970: -.greatestFiniteMagnitude).isValid)
        XCTAssertFalse(Date(timeIntervalSince1970: 1e15).isValid)
    }

    /// A plausible mistake rather than a hostile input: milliseconds passed where seconds are expected
    /// lands tens of thousands of years out, which formats and compares like any other date.
    func test_isValid_millisecondsMistakenForSeconds_isFalse() {
        let milliseconds = Date().timeIntervalSince1970 * 1000
        XCTAssertFalse(Date(timeIntervalSince1970: milliseconds * 1000).isValid)
    }

    /// The sentinels are ordinary `Date` values, but they sit far outside the convertible range.
    func test_isValid_distantPastAndFuture_areFalse() {
        XCTAssertFalse(Date.distantPast.isValid)
        XCTAssertFalse(Date.distantFuture.isValid)
    }

    func test_isValid_justOutsideTheBound_isFalse() {
        XCTAssertFalse(Date(timeIntervalSince1970: maxInterval + 1).isValid)
        XCTAssertFalse(Date(timeIntervalSince1970: -maxInterval - 1).isValid)
    }

    // MARK: - Accepted

    func test_isValid_ordinaryDates_areTrue() {
        XCTAssertTrue(Date().isValid)
        XCTAssertTrue(Date(timeIntervalSince1970: 0).isValid)
        XCTAssertTrue(Date(timeIntervalSince1970: -1_000_000).isValid)
        XCTAssertTrue(Date(timeIntervalSince1970: 1_755_000_000).isValid)
    }

    func test_isValid_atTheBound_isTrue() {
        XCTAssertTrue(Date(timeIntervalSince1970: maxInterval).isValid)
        XCTAssertTrue(Date(timeIntervalSince1970: -maxInterval).isValid)
    }

    func test_isValid_subnormalInterval_isTrue() {
        XCTAssertTrue(Date(timeIntervalSince1970: .leastNonzeroMagnitude).isValid)
    }

    // MARK: - The bound matches what the conversions can take

    /// The whole point of the bound: a date that passes can be converted. Any of these conversions would
    /// be a fatal error, not a failed assertion, if the bound were too wide.
    func test_validDatesAtTheBound_convertWithoutTrapping() {
        for interval in [maxInterval, -maxInterval] {
            let date = Date(timeIntervalSince1970: interval)

            XCTAssertEqual(date.nanosecondsSince1970Truncated, EMBInt(interval) * 1_000_000_000)
            XCTAssertEqual(date.millisecondsSince1970Truncated, EMBInt(interval) * 1000)
            XCTAssertEqual(date.serializedInterval, EMBInt(interval) * 1000)
        }
    }

    func test_validOrdinaryDate_convertsToExpectedTimestamps() {
        let date = Date(timeIntervalSince1970: 1000.5)

        XCTAssertEqual(date.millisecondsSince1970Truncated, 1_000_500)
        XCTAssertEqual(date.nanosecondsSince1970Truncated, 1_000_500_000_000)
    }
}
