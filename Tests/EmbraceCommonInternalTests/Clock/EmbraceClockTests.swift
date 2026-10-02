//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import XCTest

@testable import EmbraceCommonInternal

/// `EmbraceClock` isolates how much the device clock was *changed* over an interval by comparing it
/// against a clock that cannot be changed. These tests drive both clocks independently — the only way
/// to reproduce a clock adjustment deterministically — and pin down the two behaviours the
/// measurement depends on: that each interval is reported in isolation from the ones before it, and
/// that a reading taken while the clock is moving is discarded rather than reported as drift.
final class EmbraceClockTests: XCTestCase {

    /// Drives the wall clock and the monotonic clock separately so a test can advance one without the
    /// other, which is what a clock adjustment looks like from inside the SDK.
    private final class TestClocks {
        private(set) var wall: Date
        private(set) var monoNanos: UInt64

        /// Values the wall clock will return on the next reads, consumed one per read. Used to make
        /// the clock move *between* the two paired samples of a single measurement.
        var wallOverrides: [Date] = []

        init(wall: Date = Date(timeIntervalSince1970: 1_700_000_000), monoNanos: UInt64 = 1_000_000_000) {
            self.wall = wall
            self.monoNanos = monoNanos
        }

        /// Advances both clocks by the same amount: time passing with no clock adjustment.
        func tick(seconds: TimeInterval) {
            wall = wall.addingTimeInterval(seconds)
            monoNanos += UInt64(seconds * 1_000_000_000)
        }

        /// Moves the wall clock without advancing the monotonic clock: a pure clock adjustment.
        func shiftWallClock(seconds: TimeInterval) {
            wall = wall.addingTimeInterval(seconds)
        }

        /// Moves the monotonic clock backwards. Impossible for a real one — used to prove the clock
        /// rejects a source that is not behaving monotonically rather than deriving nonsense from it.
        func rewindMonotonic(seconds: TimeInterval) {
            monoNanos -= UInt64(seconds * 1_000_000_000)
        }

        func readWall() -> Date {
            if wallOverrides.isEmpty {
                return wall
            }
            return wallOverrides.removeFirst()
        }

        func readMono() -> UInt64 { monoNanos }
    }

    private func makeClock(_ clocks: TestClocks) -> EmbraceClock {
        EmbraceClock(wallProvider: clocks.readWall, monoProvider: clocks.readMono)
    }

    // MARK: - Measurement

    func test_measure_whenBothClocksAdvanceTogether_reportsNoDrift() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)

        XCTAssertEqual(clock.measureDriftAndReanchor(), 0)
    }

    func test_measure_whenWallClockJumpsForward_reportsPositiveDrift() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: 240)

        XCTAssertEqual(clock.measureDriftAndReanchor(), 240_000)
    }

    func test_measure_whenWallClockJumpsBackwards_reportsNegativeDrift() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: -90)

        XCTAssertEqual(clock.measureDriftAndReanchor(), -90_000)
    }

    /// The wall clock standing still while real time passes is as much an adjustment as a jump — it is
    /// what a paused or stalled clock looks like — and has to register as negative drift.
    func test_measure_whenOnlyMonotonicAdvances_reportsNegativeDrift() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 10)
        clocks.shiftWallClock(seconds: -10)

        XCTAssertEqual(clock.measureDriftAndReanchor(), -10_000)
    }

    // MARK: - Re-anchoring

    /// The whole point of re-anchoring: each part reports the clock movement that happened during it,
    /// not the total accumulated since the process started. Without this, one early clock correction
    /// would be re-reported on every part for the rest of the process.
    func test_measure_reportsEachIntervalInIsolation() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: 240)
        XCTAssertEqual(clock.measureDriftAndReanchor(), 240_000)

        // Second interval: time passes, clock is not touched again.
        clocks.tick(seconds: 60)
        XCTAssertEqual(clock.measureDriftAndReanchor(), 0)

        // Third interval: a new, smaller adjustment — reported on its own.
        clocks.tick(seconds: 10)
        clocks.shiftWallClock(seconds: -5)
        XCTAssertEqual(clock.measureDriftAndReanchor(), -5_000)
    }

    func test_reanchor_discardsDriftAccumulatedBeforeIt() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: 240)
        clock.reanchor()

        clocks.tick(seconds: 10)

        XCTAssertEqual(clock.measureDriftAndReanchor(), 0)
    }

    // MARK: - Rejected readings

    /// A clock that moves *during* the measurement makes the two paired samples disagree. Reporting
    /// either one would be reporting a number nobody can reproduce, so the measurement is dropped.
    func test_measure_whenClockMovesBetweenPairedSamples_reportsNothing() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)

        // First paired sample reads the settled value; the second reads a clock that has jumped.
        clocks.wallOverrides = [clocks.wall, clocks.wall.addingTimeInterval(5)]

        XCTAssertNil(clock.measureDriftAndReanchor())
    }

    /// Sub-millisecond disagreement between the samples is the clock ticking over, not moving, and
    /// must still produce a measurement.
    func test_measure_toleratesSubMillisecondDisagreementBetweenSamples() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        clocks.wallOverrides = [clocks.wall, clocks.wall.addingTimeInterval(0.0005)]

        XCTAssertEqual(clock.measureDriftAndReanchor(), 0)
    }

    /// A rejected reading must not leave the anchor behind, or the drift it could not explain would be
    /// rolled into the next interval and misattributed to it.
    func test_measure_whenReadingIsRejected_stillReanchors() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)

        // The clock really jumps, but the first of the two samples was taken just before it did, so
        // the pair disagrees and the reading is thrown away.
        let beforeJump = clocks.wall
        clocks.shiftWallClock(seconds: 5)
        clocks.wallOverrides = [beforeJump]
        XCTAssertNil(clock.measureDriftAndReanchor())

        // Re-anchored on the post-jump reading, so the next interval starts clean.
        clocks.tick(seconds: 10)

        XCTAssertEqual(clock.measureDriftAndReanchor(), 0)
    }

    func test_measure_whenMonotonicGoesBackwards_reportsNothing() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        // Drop the monotonic reading below the anchor it was taken from.
        clocks.rewindMonotonic(seconds: 31)

        XCTAssertNil(clock.measureDriftAndReanchor())
    }

    func test_measure_whenDriftIsImplausiblyLarge_reportsNothing() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        // Beyond the ~10 year bound the clock treats as a real adjustment.
        clocks.shiftWallClock(seconds: 20 * 365 * 24 * 60 * 60)

        XCTAssertNil(clock.measureDriftAndReanchor())
    }

    func test_measure_whenWallClockIsNotFinite_reportsNothing() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        let notFinite = Date(timeIntervalSince1970: .nan)
        clocks.wallOverrides = [notFinite, notFinite]

        XCTAssertNil(clock.measureDriftAndReanchor())
    }

    // MARK: - Concurrency

    /// Two parts ending at the same moment must not both measure against the same anchor: the interval
    /// belongs to one of them, and reporting it twice would double-count a single clock change.
    func test_measure_concurrentCallers_reportTheIntervalOnce() {
        let clocks = TestClocks()
        let clock = makeClock(clocks)

        clocks.tick(seconds: 30)
        clocks.shiftWallClock(seconds: 120)

        let results = EmbraceMutex<[EMBInt?]>([])
        let iterations = 50

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let drift = clock.measureDriftAndReanchor()
            results.withLock { $0.append(drift) }
        }

        let all = results.safeValue
        XCTAssertEqual(all.count, iterations)

        // Exactly one caller sees the 120s adjustment; everyone else finds a freshly re-anchored
        // clock and reports no movement.
        XCTAssertEqual(all.filter { $0 == 120_000 }.count, 1)
        XCTAssertEqual(all.filter { $0 == 0 }.count, iterations - 1)
    }
}
