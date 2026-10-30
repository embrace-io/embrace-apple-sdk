//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceSemantics
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    /// Measures the per-tick cost of the Smoothness hot path: `FrameTimingSource.handleTick` →
    /// the production tick handler → `FrameAccumulator`, and with focal moments, `ActivityMonitor` →
    /// `FocalMomentTracker` under touch and fling input, with and without a frame trace.
    ///
    /// Ticks are driven synchronously on main, as in `FrameTimingSourceTests`, through a source with no
    /// display link. The activity monitor doesn't observe the run loop; each tick is wrapped in the wake
    /// and sleep calls its observers would make, on a fake clock so busy time is deterministic, and
    /// touches go straight to its event handler rather than through the `sendEvent` swizzle. Simulator
    /// numbers are a regression guard only; release sign-off uses on-device numbers from
    /// `Examples/Benchmarks`.
    ///
    /// Only `test_tickCost_staysWithinBudget` can fail on cost. The `measure` tests are informational:
    /// they have no baselines, because a baseline is tied to one machine and CI hosts vary.
    final class SmoothnessOverheadTests: XCTestCase {

        /// Ticks per `measure` iteration.
        private let measuredTickCount = 100_000

        /// Ticks for the budget check, large enough to amortize timer overhead.
        private let budgetTickCount = 1_000_000

        /// Order-of-magnitude regression guard for simulator/CI runs, well above the ~1µs on-device
        /// release budget. A debug build on a loaded CI host is far slower than a real device.
        ///
        /// CI collects code coverage, which isn't skipped here like the sanitizers are. It doesn't
        /// need to be: a debug simulator build measured ~350–500 ns/tick with and without coverage,
        /// a 10x margin under this budget.
        private let ciBudgetNanosecondsPerTick: Double = 5_000

        private let frameDuration = 1.0 / 60.0

        private var source: FrameTimingSource!
        private var accumulator: FrameAccumulator!
        private var tracker: SmoothnessPartTracker!
        private var now: CFTimeInterval = 1_000
        private var currentSession: EmbraceSession?

        private var activityMonitor: ActivityMonitor?
        private var focalMomentTracker: FocalMomentTracker?
        private var momentCount = 0
        private var tracedMomentCount = 0
        private var mode: RunLoop.Mode? = .default
        private var clockNanos: UInt64 = 1_000_000_000

        private let touchBegan = MockTapEvent(mockedTouches: [MockUITouch(phase: .began)])
        private let touchMoved = MockTapEvent(mockedTouches: [MockUITouch(phase: .moved)])
        private let touchEnded = MockTapEvent(mockedTouches: [MockUITouch(phase: .ended)])

        override func setUpWithError() throws {
            try super.setUpWithError()
            try XCTSkipIfSanitizing()

            accumulator = FrameAccumulator(hangThreshold: 0.249)
            tracker = SmoothnessPartTracker(
                accumulator: accumulator,
                currentSession: { [unowned self] in self.currentSession },
                notificationCenter: NotificationCenter(),
                embraceNotificationCenter: NotificationCenter()
            )
            source = FrameTimingSource(notificationCenter: NotificationCenter(), attachesDisplayLink: false)
            source.onTick = SmoothnessCaptureService.makeTickHandler(accumulator: accumulator, environment: [:])
            now = 1_000
        }

        override func tearDown() {
            source = nil
            activityMonitor = nil
            focalMomentTracker = nil
            tracker = nil
            accumulator = nil
            currentSession = nil
            super.tearDown()
        }

        // MARK: - Helpers

        /// What the user does while ticks are delivered, in 120-tick (2s) cycles.
        private enum Input {
            case idle
            /// Touch down, 1s of moves with 1ms of main-thread work per tick, touch up, then idle long
            /// enough to settle.
            case touch
            /// `touch`, with the run loop tracking from touch down until 2/3 of a second after touch
            /// up, like a fling's deceleration.
            case fling
        }

        /// Routes ticks through the focal moment path, as `SmoothnessCaptureService` does.
        private func trackFocalMoments(recordsFrameTrace: Bool = false) {
            let activityMonitor = ActivityMonitor(
                windowEventObserver: WindowEventObserver(),
                runLoop: nil,
                currentMode: { [unowned self] in self.mode },
                clock: { [unowned self] in self.clockNanos },
                environment: [:]
            )
            let focalMomentTracker = FocalMomentTracker(frameTrace: recordsFrameTrace ? FrameTraceRecorder() : nil)
            focalMomentTracker.onMoment = { [unowned self] moment in
                self.momentCount += 1
                if moment.frameTrace != nil { self.tracedMomentCount += 1 }
            }
            source.onTick = SmoothnessCaptureService.makeTickHandler(
                accumulator: accumulator,
                focalMoments: (focalMomentTracker, activityMonitor),
                environment: [:]
            )
            self.activityMonitor = activityMonitor
            self.focalMomentTracker = focalMomentTracker
        }

        /// Delivers `count` ticks. Every 10th tick is one frame late and every 1,000th is past the
        /// hang threshold, so the drop and hang branches are exercised along with the on-time path.
        private func deliverTicks(_ count: Int, input: Input = .idle) {
            for index in 0..<count {
                var timestamp = now
                if index % 1_000 == 999 {
                    timestamp += 0.5
                } else if index % 10 == 9 {
                    timestamp += frameDuration
                }

                if let activityMonitor {
                    activityMonitor.runLoopDidWake()
                    deliverInput(input, at: index % 120, to: activityMonitor)
                }
                source.handleTick(timestamp: timestamp, targetTimestamp: timestamp + frameDuration)
                activityMonitor?.runLoopWillSleep()

                now = timestamp + frameDuration
            }
        }

        private func deliverInput(_ input: Input, at step: Int, to activityMonitor: ActivityMonitor) {
            guard input != .idle else { return }

            switch step {
            case 0: activityMonitor.handle(touchBegan)
            case 1..<60: activityMonitor.handle(touchMoved)
            case 60: activityMonitor.handle(touchEnded)
            default: break
            }
            if step <= 60 {
                clockNanos += 1_000_000
            }

            if input == .fling {
                mode = step < 100 ? .tracking : .default
            }
        }

        private func openPart() {
            let session = MockSession.with(id: .random, state: .foreground)
            currentSession = session
            tracker.open(partId: session.id)
        }

        // MARK: - Tests

        func test_tickCost_withOpenPart() {
            openPart()

            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                deliverTicks(measuredTickCount)
            }

            XCTAssertGreaterThan(tracker.openPartCounts?.expectedFrames ?? 0, 0)
        }

        /// Ticks between foreground parts still add to the running totals, which screens use.
        func test_tickCost_withoutOpenPart() {
            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                deliverTicks(measuredTickCount)
            }

            XCTAssertNil(tracker.openPartCounts)
            XCTAssertGreaterThan(accumulator.totals.expectedFrames, 0)
        }

        func test_tickCost_staysWithinBudget() {
            openPart()
            // Warm up so the first-touch cost isn't attributed to the steady state.
            deliverTicks(10_000)

            let start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            deliverTicks(budgetTickCount)
            let elapsed = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start

            let nanosecondsPerTick = Double(elapsed) / Double(budgetTickCount)
            print("[SmoothnessOverhead] \(String(format: "%.1f", nanosecondsPerTick)) ns/tick over \(budgetTickCount) ticks")

            XCTAssertLessThan(nanosecondsPerTick, ciBudgetNanosecondsPerTick)
        }

        func test_tickCost_withFocalMoments_touch() {
            trackFocalMoments()
            openPart()

            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                deliverTicks(measuredTickCount, input: .touch)
            }

            XCTAssertGreaterThan(momentCount, 0)
        }

        func test_tickCost_withFocalMoments_touch_frameTrace() {
            trackFocalMoments(recordsFrameTrace: true)
            openPart()

            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                deliverTicks(measuredTickCount, input: .touch)
            }

            XCTAssertGreaterThan(tracedMomentCount, 0)
        }

        /// Fling is the busiest input: a touch event and a tracking moment open on most ticks.
        func test_tickCost_withFocalMoments_staysWithinBudget() {
            assertFlingWithinBudget(recordsFrameTrace: false, label: "focal moments")
        }

        func test_tickCost_withFocalMoments_frameTrace_staysWithinBudget() {
            assertFlingWithinBudget(recordsFrameTrace: true, label: "focal moments with frame trace")
            XCTAssertGreaterThan(tracedMomentCount, 0)
        }

        private func assertFlingWithinBudget(recordsFrameTrace: Bool, label: String, file: StaticString = #filePath, line: UInt = #line) {
            trackFocalMoments(recordsFrameTrace: recordsFrameTrace)
            openPart()
            deliverTicks(10_000, input: .fling)

            let start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            deliverTicks(budgetTickCount, input: .fling)
            let elapsed = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start

            let nanosecondsPerTick = Double(elapsed) / Double(budgetTickCount)
            print("[SmoothnessOverhead] \(label): \(String(format: "%.1f", nanosecondsPerTick)) ns/tick over \(budgetTickCount) ticks")

            XCTAssertGreaterThan(momentCount, 0, file: file, line: line)
            XCTAssertLessThan(nanosecondsPerTick, ciBudgetNanosecondsPerTick, file: file, line: line)
        }

        func test_signpostedTickHandler_stillForwardsTicks() {
            var reported: SmoothnessFrameCounts?
            tracker.onPartClosed = { _, counts in reported = counts }
            let handler = SmoothnessCaptureService.makeTickHandler(
                accumulator: accumulator,
                environment: ["EMBSmoothnessSignposts": "1"]
            )
            openPart()

            handler(FrameTimingSource.Tick(timestamp: 0, previousTimestamp: 0, delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration))
            handler(FrameTimingSource.Tick(timestamp: 0, previousTimestamp: 0, delay: frameDuration, frameInterval: frameDuration, previousFrameInterval: frameDuration))
            tracker.invalidate()

            XCTAssertEqual(reported?.expectedFrames, 3)
            XCTAssertEqual(reported?.droppedFrames, 1)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
