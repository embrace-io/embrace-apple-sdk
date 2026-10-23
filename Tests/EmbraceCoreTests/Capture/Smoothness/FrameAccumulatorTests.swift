//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    final class FrameAccumulatorTests: XCTestCase {

        private let interval60 = 1.0 / 60.0
        private let interval120 = 1.0 / 120.0

        private var accumulator: FrameAccumulator!

        override func setUp() {
            super.setUp()
            accumulator = FrameAccumulator(hangThreshold: 0.249)
        }

        override func tearDown() {
            accumulator = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private func tick(delayInFrames: Double, frameInterval: TimeInterval? = nil, previousFrameInterval: TimeInterval? = nil) {
            let interval = frameInterval ?? interval60
            accumulator.record(
                FrameTimingSource.Tick(
                    delay: interval * delayInFrames,
                    frameInterval: interval,
                    previousFrameInterval: previousFrameInterval ?? interval
                ))
        }

        private func lateness(delay: TimeInterval, frameInterval: TimeInterval, previousFrameInterval: TimeInterval? = nil) -> TimeInterval {
            FrameAccumulator.lateness(
                of: FrameTimingSource.Tick(
                    delay: delay,
                    frameInterval: frameInterval,
                    previousFrameInterval: previousFrameInterval ?? frameInterval
                ))
        }

        // MARK: - Frame counts

        func testOnTimeTickIsOneExpectedFrame() {
            tick(delayInFrames: 0)

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 0, expectedFrames: 1, hangCount: 0))
        }

        func testLateTickCountsEachOverrunIntervalAsExpectedAndDropped() {
            tick(delayInFrames: 3)

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 3, expectedFrames: 4, hangCount: 0))
        }

        func testTotalsAccumulateAcrossTicks() {
            tick(delayInFrames: 0)
            tick(delayInFrames: 1)
            tick(delayInFrames: 0)
            tick(delayInFrames: 2)

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 3, expectedFrames: 7, hangCount: 0))
        }

        /// PerformanceSuite's inverted `notEqual` erases every single dropped frame at a steady refresh
        /// rate, and `ceil` would count jitter past a whole interval as an extra frame.
        func testOneFrameLateCountsAsOneDroppedFrame() {
            for delayInFrames in [0.5, 0.9999, 1.0, 1.0001, 1.4] {
                XCTAssertEqual(
                    FrameAccumulator.droppedFrames(lateness: interval60 * delayInFrames, frameInterval: interval60),
                    1,
                    "\(delayInFrames) frames late"
                )
            }
        }

        func testDroppedFramesRoundToNearestInterval() {
            XCTAssertEqual(FrameAccumulator.droppedFrames(lateness: interval60 * 1.5, frameInterval: interval60), 2)
            XCTAssertEqual(FrameAccumulator.droppedFrames(lateness: interval60 * 2.0001, frameInterval: interval60), 2)
            XCTAssertEqual(FrameAccumulator.droppedFrames(lateness: interval60 * 3.9, frameInterval: interval60), 4)
        }

        func testJitterBelowNoiseFloorDropsNothing() {
            tick(delayInFrames: 0.4)

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 0, expectedFrames: 1, hangCount: 0))
        }

        func testDroppedFramesAreInNativeRefreshFrames() {
            tick(delayInFrames: 1, frameInterval: interval120)

            XCTAssertEqual(accumulator.totals.droppedFrames, 1)
        }

        func testZeroFrameIntervalDropsNothing() {
            XCTAssertEqual(FrameAccumulator.droppedFrames(lateness: 1, frameInterval: 0), 0)
        }

        // MARK: - Hangs

        func testTickPastHangThresholdIsCountedAndNotCapped() {
            accumulator.record(FrameTimingSource.Tick(delay: 2, frameInterval: interval60, previousFrameInterval: interval60))

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 120, expectedFrames: 121, hangCount: 1))
        }

        func testTickAtHangThresholdIsNotAHang() {
            accumulator.record(FrameTimingSource.Tick(delay: 0.249, frameInterval: interval60, previousFrameInterval: interval60))

            XCTAssertEqual(accumulator.totals.hangCount, 0)
        }

        func testHangThresholdUpdateApplies() {
            accumulator.setHangThreshold(0.5)

            accumulator.record(FrameTimingSource.Tick(delay: 0.3, frameInterval: interval60, previousFrameInterval: interval60))
            XCTAssertEqual(accumulator.totals.hangCount, 0)

            accumulator.record(FrameTimingSource.Tick(delay: 0.6, frameInterval: interval60, previousFrameInterval: interval60))
            XCTAssertEqual(accumulator.totals.hangCount, 1)
        }

        // MARK: - Snapshot diff

        func testDifferenceOfSnapshotsIsFramesBetweenThem() {
            tick(delayInFrames: 2)
            let start = accumulator.totals

            tick(delayInFrames: 1)
            tick(delayInFrames: 0)

            XCTAssertEqual(accumulator.totals - start, SmoothnessFrameCounts(droppedFrames: 1, expectedFrames: 3, hangCount: 0))
        }

        // MARK: - Lateness

        func testMultiFrameDelayIsPassedThroughUnrounded() {
            let delay = interval60 * 3.9

            XCTAssertEqual(lateness(delay: delay, frameInterval: interval60), delay)
        }

        func testJitterBelowNoiseFloorReportsZero() {
            XCTAssertEqual(lateness(delay: 0.000_001, frameInterval: interval120), 0)
            XCTAssertEqual(lateness(delay: interval60 * 0.4, frameInterval: interval60), 0)
        }

        func testLatenessAtNoiseFloorIsPassedThroughUnchanged() {
            let delay = interval60 * FrameAccumulator.noiseFloorFraction

            XCTAssertEqual(lateness(delay: delay, frameInterval: interval60), delay)
        }

        func testNoiseFloorScalesWithFrameInterval() {
            // 0.3 of a 60Hz frame is 0.6 of a 120Hz frame.
            let delay = interval60 * 0.3

            XCTAssertEqual(lateness(delay: delay, frameInterval: interval60), 0)
            XCTAssertEqual(lateness(delay: delay, frameInterval: interval120), delay)
        }

        func testRateStepDownFrom120To60ReportsZero() {
            // The tick lands one 120Hz interval after the 120Hz tick's target.
            XCTAssertEqual(lateness(delay: interval120, frameInterval: interval60, previousFrameInterval: interval120), 0)
        }

        func testMissedFrameDuringRateStepDownIsCountedWithoutTheStep() {
            // Steps 120 → 60Hz and also misses one 60Hz frame.
            let late = lateness(delay: interval120 + interval60, frameInterval: interval60, previousFrameInterval: interval120)

            XCTAssertEqual(late, interval60, accuracy: 1e-12)
        }

        func testMissedFrameDuringRateStepUpIsCountedInFull() {
            XCTAssertEqual(lateness(delay: interval120, frameInterval: interval120, previousFrameInterval: interval60), interval120)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
