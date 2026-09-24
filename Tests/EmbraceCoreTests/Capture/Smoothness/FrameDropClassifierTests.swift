//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
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

        func testNoOpWhenNoAccumulatorIsSet() {
            classifier.currentAccumulator = nil

            classifier.handle(delay: 1.0)

            XCTAssertTrue(mockAccumulator.reportedLateness.isEmpty)
        }

        func testOnTimeFrameReportsZero() {
            classifier.handle(delay: 0)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testPartialFrameDelayIsPassedThroughUnrounded() {
            let delay = (1.0 / 60.0) * 0.5

            classifier.handle(delay: delay)

            XCTAssertEqual(mockAccumulator.reportedLateness, [delay])
        }

        func testMultiFrameDelayIsPassedThroughUnrounded() {
            let delay = (1.0 / 60.0) * 3.9

            classifier.handle(delay: delay)

            XCTAssertEqual(mockAccumulator.reportedLateness, [delay])
        }

        func testNegativeDelayReportsZero() {
            classifier.handle(delay: -0.5)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0])
        }

        func testAccumulatorSwapMidStream() {
            let secondAccumulator = MockFrameDropAccumulator()

            classifier.handle(delay: 0.025)

            classifier.currentAccumulator = secondAccumulator
            classifier.handle(delay: 0.040)

            XCTAssertEqual(mockAccumulator.reportedLateness, [0.025])
            XCTAssertEqual(secondAccumulator.reportedLateness, [0.040])
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
