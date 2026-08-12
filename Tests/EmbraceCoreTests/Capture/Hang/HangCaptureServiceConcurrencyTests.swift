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
    /// skipped there — instead every `HangLimits` below uses a multi-hour `hangThreshold`, which caps
    /// `sampleTriggerThreshold` far above this test's runtime (see `HangLimits.sampleTriggerFraction`).
    /// The sampler's poll loop therefore never reaches its trigger, so main is never suspended and no
    /// KSCrash walk runs — while the activate/stop/config-update races under test still run in full.
    final class HangCaptureServiceConcurrencyTests: XCTestCase {

        /// Thresholds high enough that the during-block trigger can never fire within the test, and
        /// distinct so that alternating between them is a genuine monitor+sampler rebuild each time.
        private static let neverTriggeringThresholds: [TimeInterval] = [3600, 1800]

        func test_concurrentConfigUpdatesAndStop_areRaceFreeAndDoNotDeadlock() {
            let otel = MockOTelSignalsHandler()
            let service = HangCaptureService(
                limits: HangLimits(hangThreshold: Self.neverTriggeringThresholds[0], hangPerSession: 6))
            service.install(otel: otel)
            service.start()

            let iterations = 500
            let group = DispatchGroup()

            // Config-update storm: alternate thresholds so each update is a real rebuild.
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                for i in 0..<iterations {
                    let threshold = Self.neverTriggeringThresholds[i % Self.neverTriggeringThresholds.count]
                    service.onConfigUpdated(
                        MockEmbraceConfigurable(hangLimits: HangLimits(hangThreshold: threshold, hangPerSession: 6)))
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
