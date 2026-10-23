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
    /// the production tick handler → `FrameAccumulator`.
    ///
    /// Ticks are driven synchronously on main, as in `FrameTimingSourceTests`, through a source with no
    /// display link. Simulator numbers are a regression guard only; release sign-off uses
    /// on-device numbers from `Examples/Benchmarks`.
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
            tracker = nil
            accumulator = nil
            currentSession = nil
            super.tearDown()
        }

        // MARK: - Helpers

        /// Delivers `count` ticks. Every 10th tick is one frame late and every 1,000th is past the
        /// hang threshold, so the drop and hang branches are exercised along with the on-time path.
        private func deliverTicks(_ count: Int) {
            for index in 0..<count {
                var timestamp = now
                if index % 1_000 == 999 {
                    timestamp += 0.5
                } else if index % 10 == 9 {
                    timestamp += frameDuration
                }
                source.handleTick(timestamp: timestamp, targetTimestamp: timestamp + frameDuration)
                now = timestamp + frameDuration
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

        func test_signpostedTickHandler_stillForwardsTicks() {
            var reported: SmoothnessFrameCounts?
            tracker.onPartClosed = { _, counts in reported = counts }
            let handler = SmoothnessCaptureService.makeTickHandler(
                accumulator: accumulator,
                environment: ["EMBSmoothnessSignposts": "1"]
            )
            openPart()

            handler(FrameTimingSource.Tick(delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration))
            handler(FrameTimingSource.Tick(delay: frameDuration, frameInterval: frameDuration, previousFrameInterval: frameDuration))
            tracker.invalidate()

            XCTAssertEqual(reported?.expectedFrames, 3)
            XCTAssertEqual(reported?.droppedFrames, 1)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
