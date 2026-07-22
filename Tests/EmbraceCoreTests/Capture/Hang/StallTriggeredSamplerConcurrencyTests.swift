//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import XCTest

    @testable import EmbraceCore

    /// Thread-safety stress for `StallTriggeredSampler`. The payoff comes when run under the
    /// **thread** sanitizer (CI runs it on `push: main` and on PRs labeled `ci:sanitizers`): the hand
    /// written lifecycle/atomic code is hammered from many threads so TSan can surface data races. In
    /// a plain run it still guards against deadlocks and crashes under contention.
    ///
    /// No `Embrace.client` is set up on purpose: `captureSample()` early-returns when no backtracer is
    /// available, so the KSCrash walk (unsafe under sanitizers) never runs — leaving only the sampler's
    /// own concurrency under test.
    ///
    /// Note: there is no per-suspend "injected delay" seam here because the suspend window is
    /// single-threaded (only the one poll thread ever suspends/walks). The real concurrency lives in
    /// the lifecycle + state surface, which this exercises directly.
    final class StallTriggeredSamplerConcurrencyTests: XCTestCase {

        func test_concurrentLifecycleAndQueries_areRaceFreeAndDoNotDeadlock() {
            let sampler = StallTriggeredSampler(
                mainThread: pthread_self(),
                triggerThreshold: 0.05,
                pollInterval: 0.01,
                logger: nil
            )
            defer { sampler.stop() }

            let threadCount = 6
            let iterations = 1_000
            let group = DispatchGroup()

            for worker in 0..<threadCount {
                DispatchQueue.global(qos: .userInitiated).async(group: group) {
                    // Cheap per-thread PRNG (no shared Foundation RNG state to muddy the race picture).
                    var seed = UInt64(worker + 1) &* 0x9E37_79B9_7F4A_7C15
                    func next() -> UInt64 {
                        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                        return seed >> 33
                    }

                    for _ in 0..<iterations {
                        switch next() % 10 {
                        case 0: sampler.start()
                        case 1: sampler.stop()
                        case 2: sampler.pause()
                        case 3: sampler.resume()
                        default:
                            let lo = next()
                            _ = sampler.samples(in: lo...(lo &+ 1_000_000))
                        }
                        if next() % 8 == 0 { sched_yield() }  // widen interleavings
                    }
                }
            }

            let outcome = group.wait(timeout: .now() + 60)
            XCTAssertEqual(
                outcome, .success,
                "Concurrency stress did not finish within the timeout — a deadlock in the sampler's "
                    + "lifecycle/state handling."
            )
        }
    }

#endif
