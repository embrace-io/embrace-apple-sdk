//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceSemantics
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    final class SmoothnessPartTrackerTests: XCTestCase {

        private let frameDuration = 1.0 / 60.0

        private var notificationCenter: NotificationCenter!
        private var embraceNotificationCenter: NotificationCenter!
        private var accumulator: FrameAccumulator!
        private var tracker: SmoothnessPartTracker!
        private var currentSession: EmbraceSession?
        private var events: [Event] = []
        private var reported: [SmoothnessFrameCounts] = []

        override func setUp() {
            super.setUp()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            currentSession = nil
            accumulator = FrameAccumulator(hangThreshold: 0.249)
            tracker = SmoothnessPartTracker(
                accumulator: accumulator,
                currentSession: { [unowned self] in self.currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            events = []
            reported = []
            tracker.onPartOpened = { [unowned self] partId in self.events.append(.opened(partId)) }
            tracker.onPartClosed = { [unowned self] partId, counts in
                self.events.append(.closed(partId))
                self.reported.append(counts)
            }
        }

        override func tearDown() {
            tracker = nil
            accumulator = nil
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
            wait(for: [drained], timeout: .defaultTimeout)
        }

        private func tick(delayInFrames: Double) {
            handle(delay: frameDuration * delayInFrames)
        }

        /// Delivers a tick at a steady 60Hz refresh rate.
        private func handle(delay: TimeInterval) {
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, previousTimestamp: 0, delay: delay, frameInterval: frameDuration, previousFrameInterval: frameDuration)))
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

        func testPartEndClosesAndReportsZerosWithNoTicks() {
            let session = startPart(.foreground)

            endPart()

            XCTAssertNil(openPartId)
            XCTAssertEqual(reportedPartIds, [session.id])
            XCTAssertEqual(reported, [SmoothnessFrameCounts()])
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
            tracker.onPartClosed = { _, _ in closedOnMain = Thread.isMainThread }

            let posted = expectation(description: "posted off main")
            var closedBeforePostReturned: Bool?
            DispatchQueue.global().async {
                self.endPart()
                closedBeforePostReturned = closedOnMain != nil
                posted.fulfill()
            }
            wait(for: [posted], timeout: .defaultTimeout)

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

        func testReportsFramesCountedWhileOpen() {
            startPart(.foreground)

            tick(delayInFrames: 0)
            tick(delayInFrames: 1.2)
            tick(delayInFrames: 3.9)
            endPart()

            XCTAssertEqual(reported, [SmoothnessFrameCounts(droppedFrames: 5, expectedFrames: 8, hangCount: 0)])
        }

        func testTicksOutsideOpenPartAreNotReported() {
            tick(delayInFrames: 5)

            startPart(.foreground)
            tick(delayInFrames: 1)
            endPart()

            tick(delayInFrames: 5)

            XCTAssertEqual(reported, [SmoothnessFrameCounts(droppedFrames: 1, expectedFrames: 2, hangCount: 0)])
        }

        func testNewPartStartsFromZero() {
            startPart(.foreground)
            tick(delayInFrames: 3)
            handle(delay: 1)
            endPart()

            startPart(.foreground)
            tick(delayInFrames: 0)
            endPart()

            XCTAssertEqual(reported.last, SmoothnessFrameCounts(droppedFrames: 0, expectedFrames: 1, hangCount: 0))
        }

        func testOpenPartCountsAreFramesSinceOpen() {
            tick(delayInFrames: 2)
            XCTAssertNil(tracker.openPartCounts)

            startPart(.foreground)
            tick(delayInFrames: 1)

            XCTAssertEqual(tracker.openPartCounts, SmoothnessFrameCounts(droppedFrames: 1, expectedFrames: 2, hangCount: 0))

            endPart()
            XCTAssertNil(tracker.openPartCounts)
        }

        func testHangsAreCountedAndNotCapped() {
            startPart(.foreground)

            handle(delay: 2)
            endPart()

            XCTAssertEqual(reported, [SmoothnessFrameCounts(droppedFrames: 120, expectedFrames: 121, hangCount: 1)])
        }

        // MARK: - Invalidate and skip

        func testInvalidateReturnsWhetherItClosed() {
            startPart(.foreground)

            XCTAssertTrue(tracker.invalidate())
            XCTAssertFalse(tracker.invalidate())
            XCTAssertEqual(reported.count, 1)
        }

        func testInvalidateClosesOpenPart() {
            let part = startPart(.foreground)
            tick(delayInFrames: 0)

            tracker.invalidate()

            XCTAssertNil(openPartId)
            XCTAssertEqual(reportedPartIds, [part.id])
            XCTAssertEqual(reported.first?.expectedFrames, 1)
        }

        func testInvalidatedTrackerOpensNoPart() {
            tracker.invalidate()

            // A later part start, cold-start swap or direct open is ignored.
            startPart(.foreground)
            postDidBecomeActive()
            drainMain()
            tracker.open()

            XCTAssertNil(openPartId)
            XCTAssertTrue(opened.isEmpty)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
