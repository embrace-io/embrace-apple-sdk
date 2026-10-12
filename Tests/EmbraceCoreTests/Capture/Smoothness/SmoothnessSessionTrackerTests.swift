//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
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
        private var tracker: SmoothnessSessionTracker!
        private var currentSession: EmbraceSession?
        private var events: [Event] = []
        private var reported: [SmoothnessSessionStats] = []

        override func setUp() {
            super.setUp()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            currentSession = nil
            tracker = SmoothnessSessionTracker(
                hangThreshold: 0.249,
                currentSession: { [unowned self] in self.currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            events = []
            reported = []
            tracker.onSessionOpened = { [unowned self] partId, _ in self.events.append(.opened(partId)) }
            tracker.onSessionClosed = { [unowned self] partId, stats in
                self.events.append(.closed(partId))
                self.reported.append(stats)
            }
        }

        override func tearDown() {
            tracker = nil
            notificationCenter = nil
            embraceNotificationCenter = nil
            currentSession = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private enum Event: Equatable {
            case opened(EmbraceIdentifier)
            case closed(EmbraceIdentifier)
        }

        private var opened: [EmbraceIdentifier] {
            events.compactMap { if case .opened(let id) = $0 { return id } else { return nil } }
        }

        private var reportedPartIds: [EmbraceIdentifier] {
            events.compactMap { if case .closed(let id) = $0 { return id } else { return nil } }
        }

        /// The part the tracker reported opening and hasn't reported closing, if any.
        private var openPartId: EmbraceIdentifier? {
            if case .opened(let id)? = events.last { return id }
            return nil
        }

        /// Makes a new part current and posts its start, as `SessionController` does.
        @discardableResult
        private func startPart(_ state: SessionState) -> EmbraceSession {
            let session = MockSession.with(id: .random, state: state)
            currentSession = session
            notificationCenter.post(name: .embraceSessionPartDidStart, object: session)
            return session
        }

        /// Posts the synchronous will-end hook for `session`, defaulting to the current part, with the
        /// part's end time as `SessionController` does.
        private func endPart(_ session: EmbraceSession? = nil, at endTime: Date = Date()) {
            embraceNotificationCenter.post(
                name: .embraceSessionPartWillEndSync,
                object: session ?? currentSession,
                userInfo: [SessionController.sessionPartWillEndSyncEndTimeKey: endTime]
            )
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
            handle(delay: frameDuration * delayInFrames)
        }

        /// Delivers a tick at a steady refresh rate with `frameInterval` between vsyncs.
        private func handle(delay: TimeInterval, frameInterval: TimeInterval? = nil) {
            let interval = frameInterval ?? frameDuration
            tracker.record(FrameTimingSource.Tick(delay: delay, frameInterval: interval, previousFrameInterval: interval))
        }

        // MARK: - Lifecycle

        func testForegroundPartStartOpens() {
            let session = startPart(.foreground)

            XCTAssertEqual(openPartId, session.id)
            XCTAssertEqual(opened, [session.id])
        }

        func testBackgroundPartStartIsIgnored() {
            startPart(.background)

            XCTAssertNil(openPartId)
            XCTAssertTrue(opened.isEmpty)
        }

        func testPartStartForNonCurrentPartIsIgnored() {
            let stale = MockSession.with(id: .random, state: .foreground)
            currentSession = MockSession.with(id: .random, state: .foreground)

            notificationCenter.post(name: .embraceSessionPartDidStart, object: stale)

            XCTAssertNil(openPartId)
        }

        func testLatePartStartAfterPartEndedIsIgnored() {
            let session = MockSession.with(id: .random, state: .foreground)
            currentSession = session

            // The part ends before its asynchronously delivered start arrives.
            endPart(session)
            notificationCenter.post(name: .embraceSessionPartDidStart, object: session)

            XCTAssertNil(openPartId)
            XCTAssertTrue(opened.isEmpty)
        }

        func testOpenForCurrentBackgroundPartIsIgnored() {
            let session = MockSession.with(id: .random, state: .background)
            currentSession = session

            tracker.open(partId: session.id)

            XCTAssertNil(openPartId)
        }

        func testStaleEndDoesNotAllowReopeningEndedPart() {
            let session = startPart(.foreground)
            endPart()

            // A stale will-end for a part that is neither open nor current.
            endPart(MockSession.with(id: .random, state: .background))
            tracker.open(partId: session.id)

            XCTAssertNil(openPartId)
            XCTAssertEqual(opened, [session.id])
        }

        func testPartEndClosesAndReports() {
            let session = startPart(.foreground)
            let before = Date()

            endPart()

            XCTAssertNil(openPartId)
            XCTAssertEqual(reported.count, 1)
            XCTAssertEqual(reportedPartIds, [session.id])
            XCTAssertEqual(reported.first?.frameCount, 0)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames, 0)
            XCTAssertGreaterThanOrEqual(reported.first?.endTime ?? .distantPast, before)
            XCTAssertLessThanOrEqual(reported.first?.endTime ?? .distantFuture, Date())
        }

        func testPartEndClosesAtPartEndTime() {
            startPart(.foreground)
            let endTime = Date(timeIntervalSinceNow: -1)

            endPart(at: endTime)

            XCTAssertEqual(reported.first?.endTime, endTime)
        }

        func testPartEndWithoutEndTimeClosesNow() {
            startPart(.foreground)
            let before = Date()

            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: currentSession)

            XCTAssertEqual(reported.count, 1)
            XCTAssertGreaterThanOrEqual(reported.first?.endTime ?? .distantPast, before)
            XCTAssertLessThanOrEqual(reported.first?.endTime ?? .distantFuture, Date())
        }

        func testEndForAnotherPartIsIgnored() {
            startPart(.foreground)

            endPart(MockSession.with(id: .random, state: .background))

            XCTAssertNotNil(openPartId)
            XCTAssertTrue(reported.isEmpty)
        }

        func testDoubleEndReportsOnce() {
            startPart(.foreground)

            endPart()
            endPart()

            XCTAssertEqual(reported.count, 1)
        }

        func testPartEndFromBackgroundThreadClosesSynchronously() {
            startPart(.foreground)
            var closedOnMain: Bool?
            tracker.onSessionClosed = { _, _ in closedOnMain = Thread.isMainThread }

            let posted = expectation(description: "posted off main")
            var closedBeforePostReturned: Bool?
            DispatchQueue.global().async {
                self.endPart()
                closedBeforePostReturned = closedOnMain != nil
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
            XCTAssertNil(openPartId)

            // `iOSSessionLifecycle` flips the same part to foreground and posts no part start.
            currentSession = MockSession.with(id: id, state: .foreground)
            postDidBecomeActive()
            drainMain()

            XCTAssertEqual(openPartId, id)
            XCTAssertEqual(opened, [id])
        }

        func testDidBecomeActiveAndPartStartOpenOnlyOnce() {
            let session = startPart(.foreground)

            postDidBecomeActive()
            drainMain()

            XCTAssertEqual(opened, [session.id])
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

            handle(delay: 1.0 / 120.0, frameInterval: 1.0 / 120.0)
            endPart()

            XCTAssertEqual(reported.first?.frameCount, 1)
            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 0.5, accuracy: accuracy)
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

            handle(delay: 0.249)
            endPart()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 14.94, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 0)
        }

        func testHangThresholdUpdateAppliesToOpenSession() {
            startPart(.foreground)

            tracker.setHangThreshold(0.5)
            handle(delay: 2.0)
            endPart()

            XCTAssertEqual(reported.first?.normalizedDroppedFrames ?? 0, 30, accuracy: accuracy)
            XCTAssertEqual(reported.first?.cappedTickCount, 1)
        }

        // MARK: - Invalidate and skip

        func testInvalidateReturnsWhetherItClosed() {
            startPart(.foreground)

            XCTAssertTrue(tracker.invalidate(at: Date()))
            XCTAssertFalse(tracker.invalidate(at: Date()))
            XCTAssertEqual(reported.count, 1)
        }

        func testInvalidateClosesOpenPart() {
            let part = startPart(.foreground)
            tick(delayInFrames: 0)

            tracker.invalidate(at: Date())

            XCTAssertNil(openPartId)
            XCTAssertEqual(reportedPartIds, [part.id])
            XCTAssertEqual(reported.first?.frameCount, 1)
        }

        func testInvalidatedTrackerOpensNoPart() {
            tracker.invalidate(at: Date())

            // A later part start, cold-start swap or direct open is ignored.
            startPart(.foreground)
            postDidBecomeActive()
            drainMain()
            tracker.openCurrentForegroundPart()

            XCTAssertNil(openPartId)
            XCTAssertTrue(opened.isEmpty)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
