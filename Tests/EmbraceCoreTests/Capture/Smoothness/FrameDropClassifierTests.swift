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

            classifier.handle(delay: 1.0, frameDuration: 1.0 / 60.0)

            XCTAssertTrue(mockAccumulator.reportedCounts.isEmpty)
        }

        func testNoOpForZeroDelay() {
            classifier.handle(delay: 0, frameDuration: 1.0 / 60.0)

            XCTAssertTrue(mockAccumulator.reportedCounts.isEmpty)
        }

        func testNoOpForDelayUnderOneFrame() {
            let frameDuration = 1.0 / 60.0

            classifier.handle(delay: frameDuration * 0.5, frameDuration: frameDuration)

            XCTAssertTrue(mockAccumulator.reportedCounts.isEmpty)
        }

        func testSingleMissedVsync() {
            let frameDuration = 1.0 / 60.0

            classifier.handle(delay: frameDuration * 1.2, frameDuration: frameDuration)

            XCTAssertEqual(mockAccumulator.reportedCounts, [1])
        }

        func testMultipleMissedVsyncs() {
            let frameDuration = 1.0 / 60.0

            classifier.handle(delay: frameDuration * 3.9, frameDuration: frameDuration)

            XCTAssertEqual(mockAccumulator.reportedCounts, [3])
        }

        func testNegativeDelayIsIgnored() {
            classifier.handle(delay: -0.5, frameDuration: 1.0 / 60.0)

            XCTAssertTrue(mockAccumulator.reportedCounts.isEmpty)
        }

        func testZeroFrameDurationIsIgnored() {
            // Guards against a division by zero if ever fed a degenerate frame duration.
            classifier.handle(delay: 1.0, frameDuration: 0)

            XCTAssertTrue(mockAccumulator.reportedCounts.isEmpty)
        }

        func testAccumulatorSwapMidStream() {
            let frameDuration = 1.0 / 60.0
            let secondAccumulator = MockFrameDropAccumulator()

            classifier.handle(delay: frameDuration * 1.5, frameDuration: frameDuration)

            classifier.currentAccumulator = secondAccumulator
            classifier.handle(delay: frameDuration * 2.5, frameDuration: frameDuration)

            XCTAssertEqual(mockAccumulator.reportedCounts, [1])
            XCTAssertEqual(secondAccumulator.reportedCounts, [2])
        }
    }

    // MARK: - Test Helpers

    private final class MockFrameDropAccumulator: FrameDropAccumulator {
        private(set) var reportedCounts: [Int] = []

        func addMissedVsyncs(_ count: Int) {
            reportedCounts.append(count)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
