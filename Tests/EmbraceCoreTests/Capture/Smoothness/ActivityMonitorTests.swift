//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import XCTest
    import UIKit
    @testable import EmbraceCore

    final class ActivityMonitorTests: SwizzlerTestCase {

        private var observer: WindowEventObserver!
        private var monitor: ActivityMonitor!
        private var now: UInt64 = 1_000_000_000
        private var mode: RunLoop.Mode? = .default

        private let threshold: UInt64 = 200_000

        override func setUpWithError() throws {
            try super.setUpWithError()
            observer = WindowEventObserver()
            monitor = ActivityMonitor(
                windowEventObserver: observer,
                runLoop: nil,
                currentMode: { [unowned self] in self.mode },
                clock: { [unowned self] in self.now },
                workThreshold: TimeInterval(threshold) / 1_000_000_000
            )
            try monitor.start()
        }

        override func tearDownWithError() throws {
            monitor.stop()
            monitor = nil
            observer = nil
            restoreSwizzleCacheAdditions()
            try super.tearDownWithError()
        }

        // MARK: - Helpers

        private func send(_ phases: UITouch.Phase...) {
            UIWindow().sendEvent(MockTapEvent(mockedTouches: Set(phases.map { MockUITouch(phase: $0) })))
        }

        private func tick(handlingTakes duration: UInt64 = 0) -> ActivityMonitor.Snapshot {
            monitor.tick { snapshot in
                now += duration
                return snapshot
            }
        }

        /// One run-loop wake lasting `busy` nanoseconds.
        private func wake(busy: UInt64) {
            monitor.runLoopDidWake()
            now += busy
            monitor.runLoopWillSleep()
        }

        // MARK: - Idle

        func test_noInput_hasNoActivity() {
            XCTAssertEqual(tick(), ActivityMonitor.Snapshot())
        }

        // MARK: - Touches

        func test_touchBegan_isActivity_andHeldTouchStaysActive() {
            send(.began)

            let first = tick()
            XCTAssertTrue(first.touchBegan)
            XCTAssertTrue(first.touchChanged)
            XCTAssertEqual(first.activeTouchCount, 1)
            XCTAssertTrue(first.hasActivity)

            // a stationary finger sends nothing: no activity, but still held
            let second = tick()
            XCTAssertFalse(second.touchBegan)
            XCTAssertFalse(second.hasActivity)
            XCTAssertEqual(second.activeTouchCount, 1)
        }

        func test_touchMoved_isActivity_withoutBegan() {
            send(.began)
            _ = tick()

            send(.moved)
            let snapshot = tick()

            XCTAssertFalse(snapshot.touchBegan)
            XCTAssertTrue(snapshot.hasActivity)
            XCTAssertEqual(snapshot.activeTouchCount, 1)
        }

        func test_touchEnded_isActivity_andReleasesTouch() {
            send(.began)
            _ = tick()

            send(.ended)
            let snapshot = tick()

            XCTAssertTrue(snapshot.hasActivity)
            XCTAssertEqual(snapshot.activeTouchCount, 0)
        }

        func test_touchCancelled_releasesTouch() {
            send(.began)
            send(.cancelled)

            XCTAssertEqual(tick().activeTouchCount, 0)
        }

        func test_multiTouch_heldUntilLastTouchEnds() {
            send(.began, .began)
            XCTAssertEqual(tick().activeTouchCount, 2)

            send(.ended, .stationary)
            XCTAssertEqual(tick().activeTouchCount, 1)

            send(.ended)
            XCTAssertEqual(tick().activeTouchCount, 0)
        }

        func test_missedEnd_correctsOnNextEvent() {
            // the first touch's end never arrives; the next event no longer carries it
            send(.began)
            XCTAssertEqual(tick().activeTouchCount, 1)

            send(.began)
            XCTAssertEqual(tick().activeTouchCount, 1)
        }

        func test_nonTouchEvent_isIgnored() {
            UIWindow().sendEvent(MockNonTouchEvent())

            XCTAssertFalse(tick().hasActivity)
        }

        func test_stop_ignoresLaterTouches() {
            monitor.stop()

            send(.began)

            XCTAssertFalse(tick().hasActivity)
        }

        // MARK: - Tracking

        func test_trackingMode_isActivity() {
            mode = .tracking

            let snapshot = tick()

            XCTAssertTrue(snapshot.isTracking)
            XCTAssertTrue(snapshot.hasActivity)
        }

        // MARK: - Main-thread work

        func test_wakeAboveThreshold_isWork() {
            wake(busy: threshold + 1)

            XCTAssertTrue(tick().didWork)
        }

        func test_wakeAtThreshold_isNotWork() {
            wake(busy: threshold)

            XCTAssertFalse(tick().hasActivity)
        }

        func test_work_isClearedAfterTick() {
            wake(busy: threshold * 10)
            _ = tick()

            XCTAssertFalse(tick().didWork)
        }

        func test_tickHandling_isNotWork() {
            // an idle tick's wake: a little dispatch, a long tick handler, a little commit
            monitor.runLoopDidWake()
            now += threshold / 4
            _ = tick(handlingTakes: threshold * 50)
            now += threshold / 4
            monitor.runLoopWillSleep()

            XCTAssertFalse(tick().didWork)
        }

        func test_workBeforeTickInSameWake_isCreditedToThatTick_once() {
            // an app animation's display link runs before ours in the same wake
            monitor.runLoopDidWake()
            now += threshold * 5
            XCTAssertTrue(tick().didWork)
            now += threshold / 4
            monitor.runLoopWillSleep()

            XCTAssertFalse(tick().didWork)
        }

        func test_workAfterTickInSameWake_isCreditedToNextTick() {
            monitor.runLoopDidWake()
            now += threshold / 4
            XCTAssertFalse(tick().didWork)
            now += threshold * 5
            monitor.runLoopWillSleep()

            XCTAssertTrue(tick().didWork)
        }

        func test_sleepWithoutWake_isNotWork() {
            now += threshold * 5
            monitor.runLoopWillSleep()

            XCTAssertFalse(tick().didWork)
        }
    }

    private final class MockNonTouchEvent: UIEvent {
        override var type: UIEvent.EventType { .motion }
        override var allTouches: Set<UITouch>? { [MockUITouch()] }
    }

#endif
