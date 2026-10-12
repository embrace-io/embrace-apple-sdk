//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    /// Ticks are driven through `handleTick` synchronously on main. The source under test has no
    /// display link, and observes a private notification center, so nothing outside the test can
    /// tick or re-arm it.
    final class FrameTimingSourceTests: XCTestCase {

        private let frameDuration = 1.0 / 60.0
        private let backgroundGap: TimeInterval = 30
        private let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForegroundNotification")

        private var notificationCenter: NotificationCenter!
        private var source: FrameTimingSource!
        private var ticks: [FrameTimingSource.Tick] = []
        private var delays: [TimeInterval] { ticks.map(\.delay) }
        private var now: CFTimeInterval = 1_000

        override func setUp() {
            super.setUp()
            notificationCenter = NotificationCenter()
            source = FrameTimingSource(notificationCenter: notificationCenter, attachesDisplayLink: false)
            ticks = []
            now = 1_000
            source.onTick = { [unowned self] tick in self.ticks.append(tick) }
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

        private func postWillEnterForeground() {
            notificationCenter.post(name: willEnterForegroundNotification, object: nil)
        }

        // MARK: - Tests

        func testWillEnterForegroundOnOtherCenterIsIgnored() {
            tick()
            skip(backgroundGap)

            NotificationCenter.default.post(name: willEnterForegroundNotification, object: nil)
            tick()

            XCTAssertEqual(delays.count, 1)
            XCTAssertEqual(delays.first ?? 0, backgroundGap, accuracy: 1e-6)
        }

        func testDisplayLinkDoesNotRetainSource() {
            weak var liveSource: FrameTimingSource?
            autoreleasepool {
                let live = FrameTimingSource(notificationCenter: notificationCenter)
                liveSource = live
                XCTAssertNotNil(liveSource)
            }

            // The display link holds its target through a weak proxy, so it doesn't keep the source alive.
            XCTAssertNil(liveSource)
        }

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

        func testRateStepDownReportsBothIntervalsAndStepDelay() throws {
            let fastInterval = 1.0 / 120.0
            let slowInterval = 1.0 / 60.0

            // A 120Hz tick promises the next frame at `now + fastInterval`, but the display steps
            // down to 60Hz and the next tick lands one 120Hz interval later than that.
            source.handleTick(timestamp: now, targetTimestamp: now + fastInterval)
            now += slowInterval
            source.handleTick(timestamp: now, targetTimestamp: now + slowInterval)

            let reported = try XCTUnwrap(ticks.first)
            XCTAssertEqual(reported.delay, fastInterval, accuracy: 1e-9)
            XCTAssertEqual(reported.frameInterval, slowInterval, accuracy: 1e-9)
            XCTAssertEqual(reported.previousFrameInterval, fastInterval, accuracy: 1e-9)
        }

        // MARK: - Pipeline

        /// The foreground part is already open when the first post-gap tick arrives, so only the
        /// source's reset keeps the gap out of it.
        func testGapIsNotReportedToForegroundPartOpenBeforeFirstTick() throws {
            let stats = try foregroundPartStatsAfterGap(resetOnWillEnterForeground: true)

            // The first tick after the reset only arms.
            XCTAssertEqual(stats.frameCount, 2)
            XCTAssertEqual(stats.cappedTickCount, 0)
            XCTAssertEqual(stats.normalizedDroppedFrames, 0, accuracy: 1e-9)
        }

        /// Control for the test above: without the reset, the gap does reach the open part.
        func testGapWithoutResetIsReportedToForegroundPartOpenBeforeFirstTick() throws {
            let stats = try foregroundPartStatsAfterGap(resetOnWillEnterForeground: false)

            XCTAssertEqual(stats.frameCount, 3)
            XCTAssertEqual(stats.cappedTickCount, 1)
            XCTAssertGreaterThan(stats.normalizedDroppedFrames, 0)
        }

        /// Foreground part, background gap, then a new foreground part that starts before the first
        /// post-gap tick. Returns the stats of that second part.
        private func foregroundPartStatsAfterGap(resetOnWillEnterForeground: Bool) throws -> SmoothnessSessionStats {
            let embraceNotificationCenter = NotificationCenter()
            var currentSession: EmbraceSession?
            let tracker = SmoothnessSessionTracker(
                hangThreshold: 0.249,
                currentSession: { currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            var reported: [SmoothnessSessionStats] = []
            tracker.onSessionClosed = { _, stats in reported.append(stats) }
            source.onTick = { [tracker] tick in tracker.record(tick) }

            let foreground = MockSession.with(id: .random, state: .foreground)
            currentSession = foreground
            notificationCenter.post(name: .embraceSessionPartDidStart, object: foreground)
            tick()
            tick()
            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: foreground)

            skip(backgroundGap)
            if resetOnWillEnterForeground {
                postWillEnterForeground()
            }
            let resumed = MockSession.with(id: .random, state: .foreground)
            currentSession = resumed
            notificationCenter.post(name: .embraceSessionPartDidStart, object: resumed)
            tick()
            tick()
            tick()
            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: resumed)

            XCTAssertEqual(reported.count, 2)
            return try XCTUnwrap(withExtendedLifetime(tracker) { reported.last })
        }
    }

#endif  // !os(watchOS) && !os(macOS)
