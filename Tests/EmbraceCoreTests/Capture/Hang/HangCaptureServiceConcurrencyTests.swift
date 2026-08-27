//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import TestSupport
    import XCTest

    @testable import EmbraceConfiguration
    @testable import EmbraceCore

    /// Thread-safety stress for `HangCaptureService`'s activate/stop/config-update surface — a path
    /// with no other concurrency coverage. Payoff is under the **thread** sanitizer (CI: `push: main`
    /// and PRs labeled `ci:sanitizers`), where it surfaces data races in the concurrent build/swap/stop
    /// of the monitor+sampler; in a plain run it guards against deadlock and crashes under contention.
    ///
    /// Note: the final post-quiesce assertion is a smoke check, not a guard on the `activate()`
    /// "stopped mid-build" (`!stored`) branch — a transient orphan there is cleaned up by the next
    /// stop/rebuild, so it wouldn't survive to the end. That branch rests on review + the isolated
    /// `onStop`/inactive-`onConfigUpdated` tests.
    ///
    /// Capture always uses `KSCrashBacktracing` in this SDK version, and that walk is unsafe under
    /// sanitizer instrumentation. Since this test's whole payoff *is* the sanitizer run, it must not be
    /// skipped there — instead every `HangLimits` below is built by ``neverTriggeringLimits(hangThreshold:)``,
    /// which pushes the during-block trigger far beyond any test runtime so the sampler's poll loop
    /// never fires, main is never suspended, and no KSCrash walk runs. The activate/stop/config-update
    /// races under test still run in full. (On 6.x this was achieved by asserting
    /// `EmbraceBacktrace.isAvailable == false`; 7.0 has no such switch, hence the threshold approach.)
    final class HangCaptureServiceConcurrencyTests: XCTestCase {

        /// Hang thresholds that are distinct, so alternating between them is a genuine monitor+sampler
        /// rebuild each time.
        private static let stormThresholds: [TimeInterval] = [3600, 1800]

        /// Limits whose during-block trigger cannot fire within this test.
        ///
        /// `sampleTriggerThreshold` **must** be passed explicitly. `HangLimits` treats
        /// `hangThreshold * sampleTriggerFraction` as a *ceiling*, not a floor, so a huge
        /// `hangThreshold` on its own leaves the trigger at its 0.15 s default. Requesting the same huge
        /// value lets that ceiling bind instead, yielding a trigger of 60% of `hangThreshold`
        /// (~36 min / ~18 min here).
        private static func neverTriggeringLimits(hangThreshold: TimeInterval) -> HangLimits {
            HangLimits(
                hangThreshold: hangThreshold,
                hangPerSession: 6,
                sampleTriggerThreshold: hangThreshold
            )
        }

        func test_concurrentConfigUpdatesAndStop_areRaceFreeAndDoNotDeadlock() {
            let otel = MockOTelSignalsHandler()
            let service = HangCaptureService(
                limits: Self.neverTriggeringLimits(hangThreshold: Self.stormThresholds[0]))
            service.install(otel: otel)
            service.start()

            // Pin the precondition the whole test rests on: if a future `HangLimits` change let the
            // trigger collapse back toward its default, the sanitizer-unsafe KSCrash walk would start
            // running in-window here. Fail loudly instead of silently changing what this test does.
            XCTAssertGreaterThan(
                service.limits.sampleTriggerThreshold, 60,
                "during-block trigger must be far beyond this test's runtime so no KSCrash walk runs")

            let iterations = 500
            let group = DispatchGroup()

            // Config-update storm: alternate thresholds so each update is a real rebuild.
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                for i in 0..<iterations {
                    let threshold = Self.stormThresholds[i % Self.stormThresholds.count]
                    service.onConfigUpdated(
                        MockEmbraceConfigurable(hangLimits: Self.neverTriggeringLimits(hangThreshold: threshold)))
                    if i % 8 == 0 { sched_yield() }  // widen interleavings
                }
            }
            // Lifecycle storm: toggle stop/start to race the activate() commit window.
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                for i in 0..<iterations {
                    service.stop()
                    service.start()
                    if i % 8 == 0 { sched_yield() }
                }
            }

            let outcome = group.wait(timeout: .now() + 60)
            XCTAssertEqual(outcome, .success, "config-update/stop stress deadlocked in HangCaptureService")

            // Quiesce, then assert no leak: after a final stop, neither sampler nor monitor remains.
            service.stop()
            XCTAssertNil(service.limitData.withLock { $0.sampler }, "no sampler should remain after stop")
            XCTAssertNil(service.limitData.withLock { $0.watchdog }, "no monitor should remain after stop")
        }
    }

#endif
