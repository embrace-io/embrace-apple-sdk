//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    final class MeasuredTickTests: XCTestCase {

        private let interval60 = 1.0 / 60.0
        private let interval120 = 1.0 / 120.0

        // MARK: - Helpers

        private func lateness(delay: TimeInterval, frameInterval: TimeInterval, previousFrameInterval: TimeInterval? = nil) -> TimeInterval {
            MeasuredTick.lateness(
                of: FrameTimingSource.Tick(
                    timestamp: 0,
                    previousTimestamp: 0,
                    delay: delay,
                    frameInterval: frameInterval,
                    previousFrameInterval: previousFrameInterval ?? frameInterval
                ))
        }

        // MARK: - Dropped frames

        /// PerformanceSuite's inverted `notEqual` erases every single dropped frame at a steady refresh
        /// rate, and `ceil` would count jitter past a whole interval as an extra frame.
        func testOneFrameLateCountsAsOneDroppedFrame() {
            for delayInFrames in [0.5, 0.9999, 1.0, 1.0001, 1.4] {
                XCTAssertEqual(
                    MeasuredTick.droppedFrames(lateness: interval60 * delayInFrames, frameInterval: interval60),
                    1,
                    "\(delayInFrames) frames late"
                )
            }
        }

        func testDroppedFramesRoundToNearestInterval() {
            XCTAssertEqual(MeasuredTick.droppedFrames(lateness: interval60 * 1.5, frameInterval: interval60), 2)
            XCTAssertEqual(MeasuredTick.droppedFrames(lateness: interval60 * 2.0001, frameInterval: interval60), 2)
            XCTAssertEqual(MeasuredTick.droppedFrames(lateness: interval60 * 3.9, frameInterval: interval60), 4)
        }

        func testZeroFrameIntervalDropsNothing() {
            XCTAssertEqual(MeasuredTick.droppedFrames(lateness: 1, frameInterval: 0), 0)
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
            let delay = interval60 * MeasuredTick.noiseFloorFraction

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
