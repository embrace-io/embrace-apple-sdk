//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    /// Tests `SmoothnessPartTracker.lateness(of:)`.
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
                SmoothnessPartTracker.lateness(
                    of: FrameTimingSource.Tick(
                        delay: delay,
                        frameInterval: frameInterval,
                        previousFrameInterval: previousFrameInterval ?? frameInterval
                    )))
        }

        // MARK: - Lateness

        func testMultiFrameDelayIsPassedThroughUnrounded() {
            let delay = interval60 * 3.9

            handle(delay: delay, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [delay])
        }

        // MARK: - Noise floor

        func testJitterBelowNoiseFloorReportsZero() {
            handle(delay: 0.000_001, frameInterval: interval120)
            handle(delay: interval60 * 0.4, frameInterval: interval60)

            XCTAssertEqual(reportedLateness, [0, 0])
        }

        func testLatenessAtNoiseFloorIsPassedThroughUnchanged() {
            let delay = interval60 * SmoothnessPartTracker.noiseFloorFraction

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

        // MARK: - Refresh rate changes

        func testRateStepDownFrom120To60ReportsZero() {
            // The tick lands one 120Hz interval after the 120Hz tick's target.
            handle(delay: interval120, frameInterval: interval60, previousFrameInterval: interval120)

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
