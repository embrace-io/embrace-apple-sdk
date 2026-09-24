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
        private let accuracy = 1e-9

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
            classifier.handle(delay: frameDuration * delayInFrames)
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
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 2.5, accuracy: accuracy)
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

        func testAccumulatesFrameCountAndNormalizedDroppedFrames() {
            postPartStart(.foreground)

            tick(delayInFrames: 0)
            tick(delayInFrames: 1.2)
            tick(delayInFrames: 3.9)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.frameCount, 3)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 5.1, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testPartialFrameDropsAreNotRoundedAway() {
            postPartStart(.foreground)

            tick(delayInFrames: 0.4)
            tick(delayInFrames: 0.4)
            tick(delayInFrames: 0.4)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 1.2, accuracy: accuracy)
        }

        func testTicksOutsideOpenSessionAreIgnored() {
            tick(delayInFrames: 5.5)

            postPartStart(.foreground)
            tick(delayInFrames: 1.5)
            postForegroundEnd()

            tick(delayInFrames: 5.5)

            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 1.5, accuracy: accuracy)
        }

        func testNewSessionStartsFromZero() {
            postPartStart(.foreground)
            tick(delayInFrames: 3.5)
            postForegroundEnd()

            postPartStart(.foreground)
            tick(delayInFrames: 0)
            postForegroundEnd()

            XCTAssertEqual(reported.last?.frameCount, 1)
            XCTAssertEqual(reported.last?.normalizedDroppedFrames, 0)
        }

        // MARK: - 60fps normalization

        func testOneMissedVsyncAt120HzIsHalfAReferenceFrame() {
            postPartStart(.foreground)

            classifier.handle(delay: 1.0 / 120.0)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 0.5, accuracy: accuracy)
        }

        func testOneMissedVsyncAt30HzIsTwoReferenceFrames() {
            postPartStart(.foreground)

            classifier.handle(delay: 1.0 / 30.0)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 2.0, accuracy: accuracy)
        }

        func testLongSessionDoesNotDrift() {
            postPartStart(.foreground)

            // One hour at 120Hz, every frame 10% of a vsync late.
            let ticks = 120 * 60 * 60
            for _ in 0..<ticks {
                classifier.handle(delay: (1.0 / 120.0) * 0.1)
            }
            postForegroundEnd()

            // 432,000 ticks * 0.05 reference frames each.
            XCTAssertEqual(reported.first?.frameCount, ticks)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 21_600, accuracy: 1e-6)
        }

        // MARK: - Hang ceiling

        func testTickPastHangThresholdIsCapped() {
            postPartStart(.foreground)

            tick(delayInFrames: 120)
            postForegroundEnd()

            // Capped to 0.249s = 14.94 reference frames.
            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        func testTickAtHangThresholdIsNotCapped() {
            postPartStart(.foreground)

            classifier.handle(delay: 0.249)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testCeilingIsRefreshRateIndependent() {
            postPartStart(.foreground)

            classifier.handle(delay: 2.0)
            postForegroundEnd()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
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
