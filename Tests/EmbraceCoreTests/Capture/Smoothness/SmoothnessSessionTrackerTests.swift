//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceSemantics
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
        private var currentSession: EmbraceSession?
        private var opened: [EmbraceIdentifier] = []
        private var reported: [SmoothnessSessionStats] = []
        private var reportedPartIds: [EmbraceIdentifier] = []

        override func setUp() {
            super.setUp()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            classifier = FrameDropClassifier()
            currentSession = nil
            tracker = SmoothnessSessionTracker(
                classifier: classifier,
                hangThreshold: 0.249,
                currentSession: { [unowned self] in self.currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            opened = []
            reported = []
            reportedPartIds = []
            tracker.onSessionOpened = { [unowned self] partId, _ in self.opened.append(partId) }
            tracker.onSessionClosed = { [unowned self] partId, stats in
                self.reportedPartIds.append(partId)
                self.reported.append(stats)
            }
        }

        override func tearDown() {
            tracker = nil
            classifier = nil
            notificationCenter = nil
            embraceNotificationCenter = nil
            currentSession = nil
            super.tearDown()
        }

        // MARK: - Helpers

        /// Makes a new part current and posts its start, as `SessionController` does.
        @discardableResult
        private func startPart(_ state: SessionState) -> EmbraceSession {
            let session = MockSession.with(id: .random, state: state)
            currentSession = session
            notificationCenter.post(name: .embraceSessionPartDidStart, object: session)
            return session
        }

        /// Posts the synchronous will-end hook for `session`, defaulting to the current part.
        private func endPart(_ session: EmbraceSession? = nil) {
            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: session ?? currentSession)
        }

        private func postDidBecomeActive() {
            notificationCenter.post(name: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil)
        }

        /// Runs the main queue past anything already enqueued on it.
        private func drainMain() {
            let drained = expectation(description: "main drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 1)
        }

        private func tick(delayInFrames: Double) {
            classifier.handle(delay: frameDuration * delayInFrames)
        }

        // MARK: - Lifecycle

        func testAttachesToClassifierForItsLifetime() {
            XCTAssertTrue(classifier.currentAccumulator === tracker)

            startPart(.foreground)
            endPart()

            XCTAssertTrue(classifier.currentAccumulator === tracker)
        }

        func testForegroundPartStartOpens() {
            let session = startPart(.foreground)

            XCTAssertTrue(tracker.isSessionOpen)
            XCTAssertEqual(tracker.openPartId, session.id)
            XCTAssertEqual(opened, [session.id])
        }

        func testBackgroundPartStartIsIgnored() {
            startPart(.background)

            XCTAssertFalse(tracker.isSessionOpen)
            XCTAssertTrue(opened.isEmpty)
        }

        func testPartStartForNonCurrentPartIsIgnored() {
            let stale = MockSession.with(id: .random, state: .foreground)
            currentSession = MockSession.with(id: .random, state: .foreground)

            notificationCenter.post(name: .embraceSessionPartDidStart, object: stale)

            XCTAssertFalse(tracker.isSessionOpen)
        }

        func testLatePartStartAfterPartEndedIsIgnored() {
            let session = MockSession.with(id: .random, state: .foreground)
            currentSession = session

            // The part ends before its asynchronously delivered start arrives.
            endPart(session)
            notificationCenter.post(name: .embraceSessionPartDidStart, object: session)

            XCTAssertFalse(tracker.isSessionOpen)
            XCTAssertTrue(opened.isEmpty)
        }

        func testPartEndClosesAndReports() {
            let session = startPart(.foreground)
            let before = Date()

            endPart()

            XCTAssertFalse(tracker.isSessionOpen)
            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reportedPartIds, [session.id])
            XCTAssertGreaterThanOrEqual(reported.first?.endTime ?? .distantPast, before)
            XCTAssertLessThanOrEqual(reported.first?.endTime ?? .distantFuture, Date())
        }

        func testZeroFramePartStillReports() {
            startPart(.foreground)

            endPart()

            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reported.first?.frameCount, 0)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames, 0)
        }

        func testEndForAnotherPartIsIgnored() {
            startPart(.foreground)

            endPart(MockSession.with(id: .random, state: .background))

            XCTAssertTrue(tracker.isSessionOpen)
            XCTAssertTrue(reported.isEmpty)
        }

        func testPartEndWithoutOpenSessionIsNoOp() {
            endPart(MockSession.with(id: .random, state: .foreground))

            XCTAssertTrue(reported.isEmpty)
        }

        func testDoubleEndReportsOnce() {
            startPart(.foreground)

            endPart()
            endPart()

            XCTAssertEqual(reported.count, 1)
        }

        func testStartWhileOpenClosesPreviousSession() {
            let first = startPart(.foreground)
            tick(delayInFrames: 2.5)

            let second = startPart(.foreground)

            XCTAssertEqual(tracker.openPartId, second.id)
            XCTAssertEqual(reportedPartIds, [first.id])
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 2.5, accuracy: accuracy)
        }

        func testPartEndFromBackgroundThreadClosesSynchronously() {
            startPart(.foreground)
            var closedOnMain: Bool?
            tracker.onSessionClosed = { _, _ in closedOnMain = Thread.isMainThread }

            let posted = expectation(description: "posted off main")
            var closedBeforePostReturned: Bool?
            DispatchQueue.global().async {
                self.endPart()
                closedBeforePostReturned = !self.tracker.isSessionOpen
                posted.fulfill()
            }
            wait(for: [posted], timeout: 1)

            XCTAssertEqual(closedOnMain, false)
            XCTAssertEqual(closedBeforePostReturned, true)
        }

        // MARK: - Cold-start swap

        func testDidBecomeActiveOpensColdStartPartSwappedToForeground() {
            let id = EmbraceIdentifier.random
            currentSession = MockSession.with(id: id, state: .background)
            postDidBecomeActive()
            drainMain()
            XCTAssertFalse(tracker.isSessionOpen)

            // `iOSSessionLifecycle` flips the same part to foreground and posts no part start.
            currentSession = MockSession.with(id: id, state: .foreground)
            postDidBecomeActive()
            drainMain()

            XCTAssertEqual(tracker.openPartId, id)
            XCTAssertEqual(opened, [id])
        }

        func testDidBecomeActiveAndPartStartOpenOnlyOnce() {
            let session = startPart(.foreground)

            postDidBecomeActive()
            drainMain()

            XCTAssertEqual(opened, [session.id])
        }

        func testColdStartPartClosesOnItsWillEnd() {
            let id = EmbraceIdentifier.random
            currentSession = MockSession.with(id: id, state: .foreground)
            postDidBecomeActive()
            drainMain()

            endPart()

            XCTAssertEqual(reportedPartIds, [id])
        }

        func testOpenCurrentForegroundPartIgnoresBackgroundPart() {
            currentSession = MockSession.with(id: .random, state: .background)

            tracker.openCurrentForegroundPart()

            XCTAssertFalse(tracker.isSessionOpen)
        }

        func testCloseOpenSessionReportsWhicheverPartIsOpen() {
            let session = startPart(.foreground)

            tracker.closeOpenSession(at: Date())

            XCTAssertEqual(reportedPartIds, [session.id])
            XCTAssertFalse(tracker.isSessionOpen)
        }

        // MARK: - Accounting

        func testAccumulatesFrameCountAndNormalizedDroppedFrames() {
            startPart(.foreground)

            tick(delayInFrames: 0)
            tick(delayInFrames: 1.2)
            tick(delayInFrames: 3.9)
            endPart()

            XCTAssertEqual(reported.first?.frameCount, 3)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 5.1, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testPartialFrameDropsAreNotRoundedAway() {
            startPart(.foreground)

            tick(delayInFrames: 0.4)
            tick(delayInFrames: 0.4)
            tick(delayInFrames: 0.4)
            endPart()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 1.2, accuracy: accuracy)
        }

        func testTicksOutsideOpenSessionAreIgnored() {
            tick(delayInFrames: 5.5)

            startPart(.foreground)
            tick(delayInFrames: 1.5)
            endPart()

            tick(delayInFrames: 5.5)

            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 1.5, accuracy: accuracy)
        }

        func testNewSessionStartsFromZero() {
            startPart(.foreground)
            tick(delayInFrames: 3.5)
            endPart()

            startPart(.foreground)
            tick(delayInFrames: 0)
            endPart()

            XCTAssertEqual(reported.last?.frameCount, 1)
            XCTAssertEqual(reported.last?.normalizedDroppedFrames, 0)
        }

        // MARK: - 60fps normalization

        func testOneMissedVsyncAt120HzIsHalfAReferenceFrame() {
            startPart(.foreground)

            classifier.handle(delay: 1.0 / 120.0)
            endPart()

            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 0.5, accuracy: accuracy)
        }

        func testOneMissedVsyncAt30HzIsTwoReferenceFrames() {
            startPart(.foreground)

            classifier.handle(delay: 1.0 / 30.0)
            endPart()

            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 2.0, accuracy: accuracy)
        }

        func testLongSessionDoesNotDrift() {
            startPart(.foreground)

            // One hour at 120Hz, every frame 10% of a vsync late.
            let ticks = 120 * 60 * 60
            for _ in 0..<ticks {
                classifier.handle(delay: (1.0 / 120.0) * 0.1)
            }
            endPart()

            // 432,000 ticks * 0.05 reference frames each.
            XCTAssertEqual(reported.first?.frameCount, ticks)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 21_600, accuracy: 1e-6)
        }

        // MARK: - Hang ceiling

        func testTickPastHangThresholdIsCapped() {
            startPart(.foreground)

            tick(delayInFrames: 120)
            endPart()

            // Capped to 0.249s = 14.94 reference frames.
            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        func testTickAtHangThresholdIsNotCapped() {
            startPart(.foreground)

            classifier.handle(delay: 0.249)
            endPart()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testCeilingIsRefreshRateIndependent() {
            startPart(.foreground)

            classifier.handle(delay: 2.0)
            endPart()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        func testHangThresholdUpdateAppliesToOpenSession() {
            startPart(.foreground)

            tracker.hangThreshold = 0.5
            classifier.handle(delay: 2.0)
            endPart()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 30, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        func testHangDoesNotCloseSession() {
            startPart(.foreground)

            tick(delayInFrames: 120)

            XCTAssertTrue(tracker.isSessionOpen)
            XCTAssertTrue(reported.isEmpty)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
