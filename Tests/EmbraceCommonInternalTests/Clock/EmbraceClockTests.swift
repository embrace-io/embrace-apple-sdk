//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommonInternal

// MARK: - Helpers

private func assertApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    tolerance: Double = 1e-9,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertLessThanOrEqual(abs(a - b), tolerance, "Expected \(a) ≈ \(b) (±\(tolerance))", file: file, line: line)
}

/// For UInt64 divisions/rounding semantics, conversion is truncating toward zero by design.
private func assertEqualU64(
    _ a: UInt64,
    _ b: UInt64,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(a, b, file: file, line: line)
}

// MARK: - Instant Construction & Conversions

final class EmbraceClockInstantConstructionTests: XCTestCase {

    func testInitSeconds() {
        let t = EmbraceClock.Instant(seconds: 1.25)
        assertApproximatelyEqual(t.secondsValue, 1.25)
        assertEqualU64(t.millisecondsValue, 1_250)
        assertEqualU64(t.nanosecondsValue, 1_250_000_000)
    }

    func testInitMilliseconds() {
        let t = EmbraceClock.Instant(milliseconds: 250)
        assertApproximatelyEqual(t.secondsValue, 0.25)
        assertEqualU64(t.millisecondsValue, 250)
        assertEqualU64(t.nanosecondsValue, 250_000_000)
    }

    func testInitNanoseconds() {
        let t = EmbraceClock.Instant(nanoseconds: 5_000_000)
        assertApproximatelyEqual(t.secondsValue, 0.005)
        assertEqualU64(t.millisecondsValue, 5)
        assertEqualU64(t.nanosecondsValue, 5_000_000)
    }

    func testFactoryMethods() {
        XCTAssertEqual(EmbraceClock.Instant.seconds(2).nanosecondsValue, 2_000_000_000)
        XCTAssertEqual(EmbraceClock.Instant.milliseconds(1500).secondsValue, 1.5)
        XCTAssertEqual(EmbraceClock.Instant.nanoseconds(750_000).millisecondsValue, 0)  // truncates
    }
}

final class EmbraceClockInstantConversionAPITests: XCTestCase {

    func testSecondsConversionMethodPreservesUnitOrConverts() {
        let a = EmbraceClock.Instant.seconds(2.0).seconds()
        assertApproximatelyEqual(a.secondsValue, 2.0)

        let b = EmbraceClock.Instant.milliseconds(500).seconds()
        assertApproximatelyEqual(b.secondsValue, 0.5)

        let c = EmbraceClock.Instant.nanoseconds(2_000_000_000).seconds()
        assertApproximatelyEqual(c.secondsValue, 2.0)
    }

    func testMillisecondsConversionMethod() {
        let a = EmbraceClock.Instant.seconds(0.75).milliseconds()
        assertEqualU64(a.millisecondsValue, 750)

        let b = EmbraceClock.Instant.nanoseconds(3_499_999).milliseconds()  // trunc
        assertEqualU64(b.millisecondsValue, 3)

        let c = EmbraceClock.Instant.milliseconds(42).milliseconds()
        assertEqualU64(c.millisecondsValue, 42)
    }

    func testNanosecondsConversionMethod() {
        let a = EmbraceClock.Instant.seconds(1.0).nanoseconds()
        assertEqualU64(a.nanosecondsValue, 1_000_000_000)

        let b = EmbraceClock.Instant.milliseconds(3).nanoseconds()
        assertEqualU64(b.nanosecondsValue, 3_000_000)

        let c = EmbraceClock.Instant.nanoseconds(7).nanoseconds()
        assertEqualU64(c.nanosecondsValue, 7)
    }
}

// MARK: - Instant Arithmetic

final class EmbraceClockInstantArithmeticTests: XCTestCase {

    func testAddition() {
        let a = EmbraceClock.Instant.seconds(1.0)
        let b = EmbraceClock.Instant.milliseconds(250)
        let sum = a + b
        assertApproximatelyEqual(sum.secondsValue, 1.25)
        assertEqualU64(sum.nanosecondsValue, 1_250_000_000)
    }

    func testSubtractionNonWrapping() {
        let a = EmbraceClock.Instant.milliseconds(1200)
        let b = EmbraceClock.Instant.milliseconds(200)
        let diff = a - b
        assertEqualU64(diff.millisecondsValue, 1_000)
    }

    func testWrappingAddition() {
        let big = EmbraceClock.Instant.nanoseconds(.max)
        let one = EmbraceClock.Instant.nanoseconds(1)
        let wrap = big &+ one
        // UInt64.max &+ 1 wraps to 0
        assertEqualU64(wrap.nanosecondsValue, 0)
    }

    func testWrappingSubtraction() {
        let small = EmbraceClock.Instant.nanoseconds(1)
        let big = EmbraceClock.Instant.nanoseconds(2)
        let wrap = small &- big
        // 1 &- 2 wraps to UInt64.max
        assertEqualU64(wrap.nanosecondsValue, .max)
    }

    func testCrossUnitArithmetic() {
        let a = EmbraceClock.Instant.seconds(2.5)  // 2_500_000_000 ns
        let b = EmbraceClock.Instant.nanoseconds(250_000)  // 0.00025 s
        let c = EmbraceClock.Instant.milliseconds(125)  // 0.125 s
        let sum = a + b + c
        assertApproximatelyEqual(sum.secondsValue, 2.5 + 0.00025 + 0.125, tolerance: 1e-12)
        assertEqualU64(sum.millisecondsValue, 2_625)  // truncation in ms
    }
}

// MARK: - EmbraceClock Behavior

final class EmbraceClockSnapshotTests: XCTestCase {

    func testCurrentProducesReasonableRealtimeDate() {
        let now = Date().timeIntervalSince1970
        let snapshot = EmbraceClock.current
        let rt = snapshot.realtime.secondsValue

        // Allow a small skew between sampling the Date() and the clock.
        assertApproximatelyEqual(rt, now, tolerance: 1.0)  // 1s is generous for CI
        XCTAssertGreaterThan(snapshot.uptime.nanosecondsValue, 0)
        XCTAssertGreaterThan(snapshot.monotonic.nanosecondsValue, 0)
    }

    func testNeverIsMax() {
        let never = EmbraceClock.never
        XCTAssertEqual(never.uptime.nanosecondsValue, .max)
        XCTAssertEqual(never.monotonic.nanosecondsValue, .max)
        XCTAssertEqual(never.realtime.nanosecondsValue, .max)
    }

    func testDateAccessorMatchesRealtime() {
        let s = EmbraceClock.current
        let derived = s.date.timeIntervalSince1970
        assertApproximatelyEqual(derived, s.realtime.secondsValue, tolerance: 1e-6)
    }

    func testClockSubtractionComponentWise() {
        // Construct deterministic clocks
        let a = makeClock(u: 2_000, m: 5_000, r: 10_000)  // ns
        let b = makeClock(u: 1_000, m: 4_000, r: 9_000)
        let d = a - b

        XCTAssertEqual(d.uptime.nanosecondsValue, 1_000)
        XCTAssertEqual(d.monotonic.nanosecondsValue, 1_000)
        XCTAssertEqual(d.realtime.nanosecondsValue, 1_000)
    }

    func testClockSubtractionWrapping() {
        let a = makeClock(u: 0, m: 0, r: 0)
        let b = makeClock(u: 1, m: 2, r: 3)
        let d = a - b
        XCTAssertEqual(d.uptime.nanosecondsValue, .max)  // 0 &- 1
        XCTAssertEqual(d.monotonic.nanosecondsValue, .max &- 1)  // 0 &- 2
        XCTAssertEqual(d.realtime.nanosecondsValue, .max &- 2)  // 0 &- 3
    }

    func testTwoSnapshotsAreNonNegativeDiffs() {
        // Not asserting monotonicity across different domains, only that self - self == 0
        let s1 = EmbraceClock.current
        let s2 = EmbraceClock.current
        let diff = s2 - s1
        // Wrapping subtraction should not wrap when s2 >= s1 in practice (very likely).
        // We'll just assert "not nonsensical": values won't be astronomically large if close in time.
        XCTAssertLessThan(diff.uptime.secondsValue, 10)  // <10s
        XCTAssertLessThan(diff.monotonic.secondsValue, 10)
        XCTAssertLessThan(diff.realtime.secondsValue, 10)
    }

    // MARK: - Private

    private func makeClock(u: UInt64, m: UInt64, r: UInt64) -> EmbraceClock {
        // Use the private initializer pattern via a small test-only extension below.
        EmbraceClock(
            uptime: .nanoseconds(u),
            monotonic: .nanoseconds(m),
            realtime: .nanoseconds(r)
        )
    }
}

// MARK: - Performance

final class EmbraceClockPerformanceTests: XCTestCase {

    func testSnapshotPerformance() {
        measure {
            _ = EmbraceClock.current
        }
    }

    func testInstantArithmeticPerformance() {
        let a = EmbraceClock.Instant.nanoseconds(1_234_567_890)
        let b = EmbraceClock.Instant.milliseconds(987)
        measure {
            var acc = EmbraceClock.Instant.nanoseconds(0)
            for _ in 0..<100_000 {
                acc = (acc &+ a) &- b
            }
            _ = acc
        }
    }
}
