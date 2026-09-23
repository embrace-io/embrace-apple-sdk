//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    final class SmoothnessSessionTrackerTests: XCTestCase {

        private let frameDuration = 1.0 / 60.0

        private var notificationCenter: NotificationCenter!
        private var embraceNotificationCenter: NotificationCenter!
        private var classifier: FrameDropClassifier!
        private var tracker: SmoothnessSessionTracker!
        private var reported: [SmoothnessSessionStats] = []

        override func setUp() {
            super.setUp()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            classifier = FrameDropClassifier()
            tracker = SmoothnessSessionTracker(
                classifier: classifier,
                hangThreshold: 0.249,
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            reported = []
            tracker.onSessionEnded = { [unowned self] in self.reported.append($0) }
        }

        override func tearDown() {
            tracker = nil
            classifier = nil
            notificationCenter = nil
            embraceNotificationCenter = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private func postPartStart(_ state: SessionState) {
            notificationCenter.post(name: .embraceSessionPartDidStart, object: MockSession.with(id: .random, state: state))
        }

        private func postForegroundEnd(_ date: Date = Date()) {
            embraceNotificationCenter.post(name: .embraceForegroundSessionDidEnd, object: date)
        }

        private func tick(delayInFrames: Double) {
            classifier.handle(delay: frameDuration * delayInFrames, frameDuration: frameDuration)
        }

        // MARK: - Lifecycle

        func testForegroundPartStartOpensAndAttaches() {
            postPartStart(.foreground)

            XCTAssertTrue(tracker.isSessionOpen)
            XCTAssertTrue(classifier.currentAccumulator === tracker)
        }

        func testBackgroundPartStartIsIgnored() {
            postPartStart(.background)

            XCTAssertFalse(tracker.isSessionOpen)
            XCTAssertNil(classifier.currentAccumulator)
        }

        func testForegroundEndClosesDetachesAndReports() {
            postPartStart(.foreground)
            let endTime = Date(timeIntervalSince1970: 1000)

            postForegroundEnd(endTime)

            XCTAssertFalse(tracker.isSessionOpen)
            XCTAssertNil(classifier.currentAccumulator)
            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reported.first?.endTime, endTime)
        }

        func testForegroundEndWithoutOpenSessionIsNoOp() {
            postForegroundEnd()

            XCTAssertTrue(reported.isEmpty)
        }

        func testDoubleEndReportsOnce() {
            postPartStart(.foreground)

            postForegroundEnd()
            postForegroundEnd()

            XCTAssertEqual(reported.count, 1)
        }

        func testStartWhileOpenClosesPreviousSession() {
            postPartStart(.foreground)
            tick(delayInFrames: 2.5)

            postPartStart(.foreground)

            XCTAssertTrue(tracker.isSessionOpen)
            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reported.first?.droppedFrames, 2)
        }

        func testForegroundEndFromBackgroundThreadClosesOnMain() {
            postPartStart(.foreground)
            let reportedOnMain = expectation(description: "reported on main")
            tracker.onSessionEnded = { _ in
                XCTAssertTrue(Thread.isMainThread)
                reportedOnMain.fulfill()
            }

            DispatchQueue.global().async { self.postForegroundEnd() }

            wait(for: [reportedOnMain], timeout: 1)
            XCTAssertFalse(tracker.isSessionOpen)
        }

        // MARK: - Accounting

        func testAccumulatesExpectedAndDroppedFrames() {
            postPartStart(.foreground)

            tick(delayInFrames: 0)  // on time: expected 1, dropped 0
            tick(delayInFrames: 1.2)  // 1 missed: expected 2, dropped 1
            tick(delayInFrames: 3.9)  // 3 missed: expected 4, dropped 3
            postForegroundEnd()

            XCTAssertEqual(reported.first?.expectedFrames, 7)
            XCTAssertEqual(reported.first?.droppedFrames, 4)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testTicksOutsideOpenSessionAreIgnored() {
            tick(delayInFrames: 5.5)

            postPartStart(.foreground)
            tick(delayInFrames: 1.5)
            postForegroundEnd()

            tick(delayInFrames: 5.5)

            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reported.first?.droppedFrames, 1)
            XCTAssertEqual(reported.first?.expectedFrames, 2)
        }

        func testNewSessionStartsFromZero() {
            postPartStart(.foreground)
            tick(delayInFrames: 3.5)
            postForegroundEnd()

            postPartStart(.foreground)
            tick(delayInFrames: 0)
            postForegroundEnd()

            XCTAssertEqual(reported.last?.expectedFrames, 1)
            XCTAssertEqual(reported.last?.droppedFrames, 0)
        }

        // MARK: - Hang ceiling

        func testTickPastHangThresholdIsCapped() {
            postPartStart(.foreground)

            // 2s stall at 60Hz = 120 missed vsyncs; ceiling is Int(0.249 * 60) = 14.
            tick(delayInFrames: 120)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.droppedFrames, 14)
            XCTAssertEqual(reported.first?.expectedFrames, 15)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        func testTickAtHangThresholdIsNotCapped() {
            postPartStart(.foreground)

            tick(delayInFrames: 14.5)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.droppedFrames, 14)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testCeilingScalesWithRefreshRate() {
            postPartStart(.foreground)
            let proMotionFrameDuration = 1.0 / 120.0

            classifier.handle(delay: 2.0, frameDuration: proMotionFrameDuration)
            postForegroundEnd()

            // Int(0.249 * 120) = 29
            XCTAssertEqual(reported.first?.droppedFrames, 29)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        func testHangDoesNotCloseSession() {
            postPartStart(.foreground)

            tick(delayInFrames: 120)

            XCTAssertTrue(tracker.isSessionOpen)
            XCTAssertTrue(reported.isEmpty)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
