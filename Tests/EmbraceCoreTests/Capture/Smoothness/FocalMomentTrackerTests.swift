//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest

    @testable import EmbraceCore

    final class FocalMomentTrackerTests: XCTestCase {

        private typealias Snapshot = ActivityMonitor.Snapshot

        private let interval = 1.0 / 60.0
        private let start: TimeInterval = 1_000

        private var tracker: FocalMomentTracker!
        private var emitted: [FocalMoment] = []
        private var now: TimeInterval = 0

        override func setUp() {
            super.setUp()
            tracker = FocalMomentTracker()
            emitted = []
            now = start
            tracker.onMoment = { [unowned self] in self.emitted.append($0) }
        }

        override func tearDown() {
            tracker = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private static let touchDown = Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 1)
        private static let touchDownWithWork = Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 1, didWork: true)
        private static let move = Snapshot(touchChanged: true, activeTouchCount: 1)
        private static let moveWithWork = Snapshot(touchChanged: true, activeTouchCount: 1, didWork: true)
        private static let held = Snapshot(activeTouchCount: 1)
        private static let lift = Snapshot(touchChanged: true)
        private static let work = Snapshot(didWork: true)
        private static let heldWork = Snapshot(activeTouchCount: 1, didWork: true)
        private static let idle = Snapshot()

        /// Delivers a tick one frame after the previous one, or `lateFrames` frames late.
        private func tick(_ activity: Snapshot, lateFrames: Double = 0) {
            now += interval * (1 + lateFrames)
            tracker.record(
                MeasuredTick(
                    FrameTimingSource.Tick(
                        timestamp: now,
                        delay: interval * lateFrames,
                        frameInterval: interval,
                        previousFrameInterval: interval
                    )),
                activity: activity
            )
        }

        /// Delivers idle ticks covering `seconds`.
        private func idle(for seconds: TimeInterval, _ activity: Snapshot = idle) {
            for _ in 0..<Int((seconds / interval).rounded()) {
                tick(activity)
            }
        }

        // MARK: - Start

        func testActivityWithoutTouchOpensNothing() {
            tick(Self.lift)
            tick(Self.work)
            tick(Snapshot(isTracking: true))

            tracker.interrupt()

            XCTAssertTrue(emitted.isEmpty)
        }

        func testTouchDownOpensMoment() {
            tick(Self.touchDownWithWork)

            tracker.interrupt()

            XCTAssertEqual(emitted.count, 1)
        }

        func testMoveWithTouchHeldOpensMoment() {
            tick(Self.moveWithWork)

            tracker.interrupt()

            XCTAssertEqual(emitted.count, 1)
        }

        func testStartIsBackDatedByLateness() {
            tick(Self.touchDownWithWork, lateFrames: 2)
            let arrival = now
            tick(Self.lift)
            idle(for: 0.2)

            XCTAssertEqual(emitted.single?.start ?? 0, arrival - 2 * interval, accuracy: 1e-9)
        }

        // MARK: - Settle

        func testSettlesAfterIdleThresholdOnceLifted() {
            tick(Self.touchDownWithWork)
            tick(Self.lift)
            let lastActivity = now

            idle(for: 0.1 - interval)
            XCTAssertTrue(emitted.isEmpty, "one tick short of the idle threshold")

            idle(for: 2 * interval)
            let moment = emitted.single
            XCTAssertEqual(moment?.outcome, .settled)
            XCTAssertEqual(moment?.end, lastActivity)
            XCTAssertEqual(moment?.frameCount, 2)
        }

        func testHeldTouchUsesHeldThreshold() {
            tick(Self.touchDownWithWork)

            idle(for: 0.5 - interval, Self.held)
            XCTAssertTrue(emitted.isEmpty, "one tick short of the held threshold")

            idle(for: 2 * interval, Self.held)
            XCTAssertEqual(emitted.single?.outcome, .settled)
        }

        func testLiftTightensThresholdFromTheLift() {
            tick(Self.touchDownWithWork)
            idle(for: 0.3, Self.held)
            tick(Self.lift)

            idle(for: 0.1 - interval)
            XCTAssertTrue(emitted.isEmpty)

            idle(for: 2 * interval)
            XCTAssertEqual(emitted.count, 1)
        }

        func testMoveRefreshesHeldThreshold() {
            tick(Self.touchDownWithWork)
            idle(for: 0.4, Self.held)
            tick(Self.move)

            idle(for: 0.4, Self.held)
            XCTAssertTrue(emitted.isEmpty, "the move pushed the deadline out")

            idle(for: 0.1 + interval, Self.held)
            XCTAssertEqual(emitted.count, 1)
        }

        func testMoveAfterHeldSettleOpensNewMoment() {
            tick(Self.touchDownWithWork)
            idle(for: 0.5 + interval, Self.held)
            XCTAssertEqual(emitted.count, 1)

            tick(Self.moveWithWork)
            tracker.interrupt()
            XCTAssertEqual(emitted.map(\.outcome), [.settled, .interrupted])
        }

        func testLiftAfterSettleOpensNothing() {
            tick(Self.touchDownWithWork)
            idle(for: 0.5 + interval, Self.held)

            tick(Self.lift)
            tick(Self.work)
            tracker.interrupt()

            XCTAssertEqual(emitted.count, 1)
        }

        func testContinuousWorkHasNoMaximumDuration() {
            tick(Self.touchDownWithWork)
            tick(Self.lift)
            idle(for: 10, Self.work)
            XCTAssertTrue(emitted.isEmpty)

            tracker.interrupt()
            XCTAssertEqual(emitted.single?.outcome, .interrupted)
        }

        // MARK: - Frame counts

        func testIdleTicksBetweenActivityAreIncluded() {
            tick(Self.touchDownWithWork)
            idle(for: 0.2, Self.held)
            tick(Self.lift)
            idle(for: 0.2)

            XCTAssertEqual(emitted.single?.frameCount, 1 + 12 + 1)
        }

        func testNormalizedDroppedFramesSumsLatenessAt60fps() {
            tick(Self.touchDownWithWork, lateFrames: 1)
            tick(Self.heldWork, lateFrames: 3)
            tick(Self.lift)
            idle(for: 0.2)

            XCTAssertEqual(emitted.single?.normalizedDroppedFrames ?? 0, 4, accuracy: 1e-9)
        }

        func testNormalizedDroppedFramesUses60fpsReferenceAt120Hz() {
            let fast = 1.0 / 120.0
            now += fast
            tracker.record(
                MeasuredTick(FrameTimingSource.Tick(timestamp: now, delay: 2 * fast, frameInterval: fast, previousFrameInterval: fast)),
                activity: Self.touchDownWithWork
            )
            tracker.interrupt()

            XCTAssertEqual(emitted.single?.normalizedDroppedFrames ?? 0, 1, accuracy: 1e-9)
        }

        func testStalledTickPastThresholdIsCountedBeforeSettle() {
            tick(Self.touchDownWithWork)
            tick(Self.lift)

            // Main was blocked for 30 frames; the late tick carries that work.
            tick(Self.work, lateFrames: 30)
            let stallEnd = now
            idle(for: 0.2)

            let moment = emitted.single
            XCTAssertEqual(moment?.end, stallEnd)
            XCTAssertEqual(moment?.frameCount, 3)
            XCTAssertEqual(moment?.normalizedDroppedFrames ?? 0, 30, accuracy: 1e-9)
        }

        // MARK: - Dropped moments

        func testTouchOnlyMomentIsDropped() {
            tick(Self.touchDown)
            tick(Self.lift)
            idle(for: 0.2)

            XCTAssertTrue(emitted.isEmpty)
        }

        func testScrollTrackingCountsAsRendered() {
            tick(Self.touchDown)
            tick(Snapshot(touchChanged: true, isTracking: true))
            idle(for: 0.2)

            XCTAssertEqual(emitted.count, 1)
        }

        // MARK: - Multi-touch

        func testSecondTouchDoesNotOpenNewMoment() {
            tick(Self.touchDownWithWork)
            tick(Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 2))
            tick(Snapshot(touchChanged: true, activeTouchCount: 1))

            idle(for: 0.5 - interval, Self.held)
            XCTAssertTrue(emitted.isEmpty, "held while any touch is down")

            tick(Self.lift)
            idle(for: 0.2)
            XCTAssertEqual(emitted.single?.frameCount, 3 + 29 + 1)
        }

        // MARK: - Interrupt

        func testInterruptEndsAtLastActivity() {
            tick(Self.touchDownWithWork)
            let lastActivity = now
            idle(for: 0.05, Self.held)

            tracker.interrupt()

            let moment = emitted.single
            XCTAssertEqual(moment?.outcome, .interrupted)
            XCTAssertEqual(moment?.end, lastActivity)
            XCTAssertEqual(moment?.frameCount, 1)
        }

        // MARK: - Thresholds

        func testAppliedThresholdsAreReported() {
            tracker = FocalMomentTracker(idleThreshold: 0.2, heldIdleThreshold: 0.8)
            tracker.onMoment = { [unowned self] in self.emitted.append($0) }

            tick(Self.touchDownWithWork)
            tick(Self.lift)
            idle(for: 0.2 - interval)
            XCTAssertTrue(emitted.isEmpty)

            idle(for: 2 * interval)
            XCTAssertEqual(emitted.single?.idleThreshold, 0.2)
            XCTAssertEqual(emitted.single?.heldIdleThreshold, 0.8)
        }
    }

    extension Array {
        fileprivate var single: Element? {
            count == 1 ? first : nil
        }
    }

#endif  // !os(watchOS) && !os(macOS)
