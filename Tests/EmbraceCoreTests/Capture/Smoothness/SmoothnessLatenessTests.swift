//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    /// Tests `SmoothnessSessionTracker.lateness(of:)`.
    final class SmoothnessLatenessTests: XCTestCase {

        private var reportedLateness: [TimeInterval] = []

        override func setUp() {
            super.setUp()
            reportedLateness = []
        }

        // MARK: - Helpers

        private let interval60 = 1.0 / 60.0
        private let interval120 = 1.0 / 120.0

        private func handle(delay: TimeInterval, frameInterval: TimeInterval, previousFrameInterval: TimeInterval? = nil) {
            reportedLateness.append(
                SmoothnessSessionTracker.lateness(
                    of: FrameTimingSource.Tick(
                        delay: delay,
                        frameInterval: frameInterval,
                        previousFrameInterval: previousFrameInterval ?? frameInterval
                    )))
        }

        // MARK: - Lateness

        func testOnTimeFrameReportsZero() {
            handle(delay: 0, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [0])
        }

        func testNegativeDelayReportsZero() {
            handle(delay: -0.5, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [0])
        }

        func testOneMissedVsyncIsPassedThroughAt60And120Hz() {
            handle(delay: interval60, frameInterval: interval60)
            handle(delay: interval120, frameInterval: interval120)

            XCTAssertEqual(reportedLateness, [interval60, interval120])
        }

        func testTwoMissedVsyncsArePassedThroughAt60And120Hz() {
            handle(delay: 2 * interval60, frameInterval: interval60)
            handle(delay: 2 * interval120, frameInterval: interval120)

            XCTAssertEqual(reportedLateness, [2 * interval60, 2 * interval120])
        }

        func testMultiFrameDelayIsPassedThroughUnrounded() {
            let delay = interval60 * 3.9

            handle(delay: delay, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [delay])
        }

        func testHangSizedDelayIsPassedThroughUncapped() {
            handle(delay: 2.0, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [2.0])
        }

        // MARK: - Noise floor

        func testJitterBelowNoiseFloorReportsZero() {
            handle(delay: 0.000_001, frameInterval: interval120)
            handle(delay: interval60 * 0.4, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [0, 0])
        }

        func testLatenessAtNoiseFloorIsPassedThroughUnchanged() {
            let delay = interval60 * SmoothnessSessionTracker.noiseFloorFraction

            handle(delay: delay, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [delay])
        }

        func testNoiseFloorScalesWithFrameInterval() {
            // 0.3 of a 60Hz frame is 0.6 of a 120Hz frame.
            let delay = interval60 * 0.3

            handle(delay: delay, frameInterval: interval60)
            handle(delay: delay, frameInterval: interval120)

            XCTAssertEqual(reportedLateness, [0, delay])
        }

        func testJitterDoesNotAccumulateOverLongSessions() {
            // One hour at 120Hz, every tick 1µs late.
            for _ in 0..<(120 * 60 * 60) {
                handle(delay: 0.000_001, frameInterval: interval120)
            }

            XCTAssertEqual(reportedLateness.reduce(0, +), 0)
        }

        // MARK: - Refresh rate changes

        func testRateStepDownFrom120To60ReportsZero() {
            // The tick lands one 120Hz interval after the 120Hz tick's target.
            handle(delay: interval120, frameInterval: interval60, previousFrameInterval: interval120)

            XCTAssertEqual(reportedLateness, [0])
        }

        func testRateStepDownFrom120To24ReportsZero() {
            let interval24 = 1.0 / 24.0

            handle(delay: interval24 - interval120, frameInterval: interval24, previousFrameInterval: interval120)

            XCTAssertEqual(reportedLateness, [0])
        }

        func testRateStepUpFrom60To120ReportsZero() {
            handle(delay: 0, frameInterval: interval120, previousFrameInterval: interval60)

            XCTAssertEqual(reportedLateness, [0])
        }

        func testMissedFrameDuringRateStepDownIsCountedWithoutTheStep() {
            // Steps 120 → 60Hz and also misses one 60Hz frame.
            handle(delay: interval120 + interval60, frameInterval: interval60, previousFrameInterval: interval120)

            XCTAssertEqual(reportedLateness.first ?? 0, interval60, accuracy: 1e-12)
        }

        func testMissedFrameDuringRateStepUpIsCountedInFull() {
            handle(delay: interval120, frameInterval: interval120, previousFrameInterval: interval60)

            XCTAssertEqual(reportedLateness, [interval120])
        }
    }

#endif  // !os(watchOS) && !os(macOS)
