//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    final class FrameDropClassifierTests: XCTestCase {

        private var classifier: FrameDropClassifier!
        private var mockAccumulator: MockFrameDropAccumulator!

        override func setUp() {
            super.setUp()
            classifier = FrameDropClassifier()
            mockAccumulator = MockFrameDropAccumulator()
            classifier.currentAccumulator = mockAccumulator
        }

        override func tearDown() {
            classifier = nil
            mockAccumulator = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private let interval60 = 1.0 / 60.0
        private let interval120 = 1.0 / 120.0

        private func handle(delay: TimeInterval, frameInterval: TimeInterval, previousFrameInterval: TimeInterval? = nil) {
            classifier.handle(
                FrameTimingSource.Tick(
                    delay: delay,
                    frameInterval: frameInterval,
                    previousFrameInterval: previousFrameInterval ?? frameInterval
                ))
        }

        // MARK: - Accumulator

        func testNoOpWhenNoAccumulatorIsSet() {
            classifier.currentAccumulator = nil

            handle(delay: 1.0, frameInterval: interval60)

            XCTAssertTrue(mockAccumulator.reportedLateness.isEmpty)
        }

        func testNoOpAfterAccumulatorIsDeallocated() {
            var transient: MockFrameDropAccumulator? = MockFrameDropAccumulator()
            classifier.currentAccumulator = transient
            transient = nil

            XCTAssertNil(classifier.currentAccumulator)
            handle(delay: 1.0, frameInterval: interval60)
        }

        func testAccumulatorSwapMidStream() {
            let secondAccumulator = MockFrameDropAccumulator()

            handle(delay: 0.025, frameInterval: interval60)

            classifier.currentAccumulator = secondAccumulator
            handle(delay: 0.040, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0.025])
            XCTAssertEqual(secondAccumulator.reportedLateness, [0.040])
        }

        // MARK: - Lateness

        func testOnTimeFrameReportsZero() {
            handle(delay: 0, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testNegativeDelayReportsZero() {
            handle(delay: -0.5, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testOneMissedVsyncIsPassedThroughAt60And120Hz() {
            handle(delay: interval60, frameInterval: interval60)
            handle(delay: interval120, frameInterval: interval120)

            XCTAssertEqual(mockAccumulator.reportedLateness, [interval60, interval120])
        }

        func testTwoMissedVsyncsArePassedThroughAt60And120Hz() {
            handle(delay: 2 * interval60, frameInterval: interval60)
            handle(delay: 2 * interval120, frameInterval: interval120)

            XCTAssertEqual(mockAccumulator.reportedLateness, [2 * interval60, 2 * interval120])
        }

        func testMultiFrameDelayIsPassedThroughUnrounded() {
            let delay = interval60 * 3.9

            handle(delay: delay, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [delay])
        }

        func testHangSizedDelayIsPassedThroughForTrackerToCap() {
            handle(delay: 2.0, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [2.0])
        }

        // MARK: - Noise floor

        func testJitterBelowNoiseFloorReportsZero() {
            handle(delay: 0.000_001, frameInterval: interval120)
            handle(delay: interval60 * 0.4, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0, 0])
        }

        func testLatenessAtNoiseFloorIsPassedThroughUnchanged() {
            let delay = interval60 * FrameDropClassifier.noiseFloorFraction

            handle(delay: delay, frameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [delay])
        }

        func testNoiseFloorScalesWithFrameInterval() {
            // 0.3 of a 60Hz frame is 0.6 of a 120Hz frame.
            let delay = interval60 * 0.3

            handle(delay: delay, frameInterval: interval60)
            handle(delay: delay, frameInterval: interval120)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0, delay])
        }

        func testJitterDoesNotAccumulateOverLongSessions() {
            // One hour at 120Hz, every tick 1µs late.
            for _ in 0..<(120 * 60 * 60) {
                handle(delay: 0.000_001, frameInterval: interval120)
            }

            XCTAssertEqual(mockAccumulator.reportedLateness.reduce(0, +), 0)
        }

        // MARK: - Refresh rate changes

        func testRateStepDownFrom120To60ReportsZero() {
            // The tick lands one 120Hz interval after the 120Hz tick's target.
            handle(delay: interval120, frameInterval: interval60, previousFrameInterval: interval120)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testRateStepDownFrom120To24ReportsZero() {
            let interval24 = 1.0 / 24.0

            handle(delay: interval24 - interval120, frameInterval: interval24, previousFrameInterval: interval120)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testRateStepUpFrom60To120ReportsZero() {
            handle(delay: 0, frameInterval: interval120, previousFrameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testMissedFrameDuringRateStepDownIsCountedWithoutTheStep() {
            // Steps 120 → 60Hz and also misses one 60Hz frame.
            handle(delay: interval120 + interval60, frameInterval: interval60, previousFrameInterval: interval120)

            XCTAssertEqual(mockAccumulator.reportedLateness.first ?? 0, interval60, accuracy: 1e-12)
        }

        func testMissedFrameDuringRateStepUpIsCountedInFull() {
            handle(delay: interval120, frameInterval: interval120, previousFrameInterval: interval60)

            XCTAssertEqual(mockAccumulator.reportedLateness, [interval120])
        }
    }

    // MARK: - Test Helpers

    private final class MockFrameDropAccumulator: FrameDropAccumulator {
        private(set) var reportedLateness: [TimeInterval] = []

        func recordFrame(lateBy: TimeInterval) {
            reportedLateness.append(lateBy)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
