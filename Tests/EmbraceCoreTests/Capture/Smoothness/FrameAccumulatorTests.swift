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
                MeasuredTick(
                    FrameTimingSource.Tick(
                        delay: interval * delayInFrames,
                        frameInterval: interval,
                        previousFrameInterval: previousFrameInterval ?? interval
                    )))
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

        func testJitterBelowNoiseFloorDropsNothing() {
            tick(delayInFrames: 0.4)

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 0, expectedFrames: 1, hangCount: 0))
        }

        func testDroppedFramesAreInNativeRefreshFrames() {
            tick(delayInFrames: 1, frameInterval: interval120)

            XCTAssertEqual(accumulator.totals.droppedFrames, 1)
        }

        // MARK: - Hangs

        func testTickPastHangThresholdIsCountedAndNotCapped() {
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(delay: 2, frameInterval: interval60, previousFrameInterval: interval60)))

            XCTAssertEqual(accumulator.totals, SmoothnessFrameCounts(droppedFrames: 120, expectedFrames: 121, hangCount: 1))
        }

        func testTickAtHangThresholdIsNotAHang() {
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(delay: 0.249, frameInterval: interval60, previousFrameInterval: interval60)))

            XCTAssertEqual(accumulator.totals.hangCount, 0)
        }

        func testHangThresholdUpdateApplies() {
            accumulator.setHangThreshold(0.5)

            accumulator.record(MeasuredTick(FrameTimingSource.Tick(delay: 0.3, frameInterval: interval60, previousFrameInterval: interval60)))
            XCTAssertEqual(accumulator.totals.hangCount, 0)

            accumulator.record(MeasuredTick(FrameTimingSource.Tick(delay: 0.6, frameInterval: interval60, previousFrameInterval: interval60)))
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
    }

#endif  // !os(watchOS) && !os(macOS)
