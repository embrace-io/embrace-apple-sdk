//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    /// Ticks are driven through `handleTick` synchronously on main. The real display link can't
    /// interleave, since it only fires on a run loop turn, and none happens inside a test body.
    final class FrameTimingSourceTests: XCTestCase {

        private let frameDuration = 1.0 / 60.0
        private let backgroundGap: TimeInterval = 30

        private var notificationCenter: NotificationCenter!
        private var source: FrameTimingSource!
        private var delays: [TimeInterval] = []
        private var now: CFTimeInterval = 1_000

        override func setUp() {
            super.setUp()
            notificationCenter = NotificationCenter()
            source = FrameTimingSource()
            delays = []
            now = 1_000
            source.onTick = { [unowned self] delay in self.delays.append(delay) }
            // Discard anything a real tick armed before the test body.
            postWillEnterForeground()
        }

        override func tearDown() {
            source = nil
            notificationCenter = nil
            super.tearDown()
        }

        // MARK: - Helpers

        /// Delivers an on-time tick at `now`, then advances `now` by one frame.
        private func tick() {
            source.handleTick(timestamp: now, targetTimestamp: now + frameDuration)
            now += frameDuration
        }

        private func skip(_ interval: TimeInterval) {
            now += interval
        }

        /// `FrameTimingSource` only observes the default center.
        private func postWillEnterForeground() {
            NotificationCenter.default.post(name: Notification.Name("UIApplicationWillEnterForegroundNotification"), object: nil)
        }

        // MARK: - Tests

        func testFirstTickOnlyArms() {
            tick()

            XCTAssertTrue(delays.isEmpty)
        }

        func testOnTimeTicksReportZeroDelay() {
            tick()
            tick()
            tick()

            XCTAssertEqual(delays.count, 2)
            XCTAssertEqual(delays.max() ?? 1, 0, accuracy: 1e-9)
        }

        func testGapWithoutForegroundResetIsReported() {
            tick()
            skip(backgroundGap)
            tick()

            XCTAssertEqual(delays.count, 1)
            XCTAssertEqual(delays.first ?? 0, backgroundGap, accuracy: 1e-6)
        }

        func testWillEnterForegroundRearmsSoGapIsNotReported() {
            tick()
            tick()
            skip(backgroundGap)

            postWillEnterForeground()
            tick()
            tick()

            // One delay before the gap, one after re-arming, none spanning it.
            XCTAssertEqual(delays.count, 2)
            XCTAssertEqual(delays.max() ?? 1, 0, accuracy: 1e-9)
        }

        // MARK: - Pipeline

        /// Background → foreground through source, classifier and tracker, in the order UIKit and
        /// `SessionController` deliver it: part ends on background, will-enter-foreground, then the
        /// next foreground part starts from did-become-active.
        func testBackgroundGapDoesNotReachNextForegroundPart() throws {
            let embraceNotificationCenter = NotificationCenter()
            let classifier = FrameDropClassifier()
            var currentSession: EmbraceSession?
            let tracker = SmoothnessSessionTracker(
                classifier: classifier,
                hangThreshold: 0.249,
                currentSession: { currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            var reported: [SmoothnessSessionStats] = []
            tracker.onSessionClosed = { _, stats in reported.append(stats) }
            source.onTick = { [classifier] delay in classifier.handle(delay: delay) }

            func startPart(_ state: SessionState) {
                let session = MockSession.with(id: .random, state: state)
                currentSession = session
                notificationCenter.post(name: .embraceSessionPartDidStart, object: session)
            }
            func endPart() {
                embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: currentSession)
            }

            startPart(.foreground)
            tick()
            tick()
            endPart()
            startPart(.background)

            skip(backgroundGap)
            postWillEnterForeground()
            // Ticks between will-enter-foreground and the foreground part starting are dropped.
            tick()
            tick()
            endPart()
            startPart(.foreground)
            tick()
            tick()
            endPart()

            XCTAssertEqual(reported.count, 2)
            let resumed = try XCTUnwrap(reported.last)
            XCTAssertEqual(resumed.frameCount, 2)
            XCTAssertEqual(resumed.normalizedDroppedFrames, 0, accuracy: 1e-9)
            XCTAssertEqual(resumed.cappedTickCount, 0)
        }

        /// If a tick could land before will-enter-foreground, the gap is reported by the source but
        /// no part is open yet, so the tracker still drops it.
        func testGapTickBeforeResetIsDroppedByClosedTracker() throws {
            let embraceNotificationCenter = NotificationCenter()
            let classifier = FrameDropClassifier()
            var currentSession: EmbraceSession?
            let tracker = SmoothnessSessionTracker(
                classifier: classifier,
                hangThreshold: 0.249,
                currentSession: { currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            var reported: [SmoothnessSessionStats] = []
            tracker.onSessionClosed = { _, stats in reported.append(stats) }
            source.onTick = { [classifier] delay in classifier.handle(delay: delay) }

            let foreground = MockSession.with(id: .random, state: .foreground)
            currentSession = foreground
            notificationCenter.post(name: .embraceSessionPartDidStart, object: foreground)
            tick()
            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: foreground)

            skip(backgroundGap)
            tick()  // Gap tick, before the reset.
            postWillEnterForeground()

            let resumed = MockSession.with(id: .random, state: .foreground)
            currentSession = resumed
            notificationCenter.post(name: .embraceSessionPartDidStart, object: resumed)
            tick()
            tick()
            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: resumed)

            let stats = try XCTUnwrap(reported.last)
            XCTAssertEqual(stats.frameCount, 1)
            XCTAssertEqual(stats.cappedTickCount, 0)
            XCTAssertEqual(stats.normalizedDroppedFrames, 0, accuracy: 1e-9)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
