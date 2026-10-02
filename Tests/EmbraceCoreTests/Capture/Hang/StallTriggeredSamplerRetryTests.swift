//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceStorageInternal
    import Foundation
    import XCTest

    @testable import EmbraceCore

    /// Covers how the sampler handles captures that come back with no frames: they are retried on
    /// the next poll tick, at most `maxCaptureAttemptsPerEpisode` times per stall episode.
    ///
    /// Captures go through a `ScriptedBacktracer`, so no real stack walk runs.
    final class StallTriggeredSamplerRetryTests: XCTestCase {

        private let pollInterval: TimeInterval = 0.01
        private var backtracer: ScriptedBacktracer!
        private var sampler: StallTriggeredSampler!

        override func tearDown() {
            sampler?.stop()
            sampler = nil
            Embrace.client = nil
            super.tearDown()
        }

        private func givenSampler(failingCaptures failures: Int) throws {
            backtracer = ScriptedBacktracer(failures: failures)

            // Dispatch once through the `@objc` protocol so the ObjC method cache is warm before the
            // method is ever called while main is suspended.
            let warmUp = UnsafeMutablePointer<FrameAddress>.allocate(capacity: 1)
            defer { warmUp.deallocate() }
            _ = (backtracer as Backtracer).backtrace(of: pthread_self(), into: warmUp, capacity: 0)

            let options = Embrace.Options(
                appId: "myApp",
                captureServices: [],
                crashReporter: nil,
                backtracer: backtracer,
                symbolicator: nil
            )
            Embrace.client = try Embrace(options: options, embraceStorage: EmbraceStorage.createInMemoryDb())

            sampler = StallTriggeredSampler(
                mainThread: pthread_self(),  // XCTest runs this on the main thread
                triggerThreshold: HangLimits.minSampleTriggerThreshold,
                pollInterval: pollInterval,
                logger: nil
            )
            sampler.start()
        }

        /// Keeps main busy (one stall episode) until `condition` holds, then for `extraPolls` more
        /// poll intervals so any capture that should not happen would have had the chance to.
        ///
        /// The stall is scheduled with `asyncAfter` so the main run loop goes idle before it starts;
        /// that is what lets the sampler see each call as a new episode.
        @MainActor
        private func stallMainThread(until condition: @escaping () -> Bool, extraPolls: Int = 0) {
            let done = expectation(description: "main unblocked")
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { [pollInterval] in
                let deadline = Date().addingTimeInterval(5)
                while !condition() && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.001)
                }
                Thread.sleep(forTimeInterval: pollInterval * Double(extraPolls))
                done.fulfill()
            }
            wait(for: [done], timeout: 10)
        }

        private var samples: [MainThreadStackSample] {
            sampler.samples(in: 0...UInt64.max)
        }

        @MainActor
        func test_emptyCapture_isRetriedWithinTheSameEpisode() throws {
            let failures = StallTriggeredSampler.maxCaptureAttemptsPerEpisode - 1
            try givenSampler(failingCaptures: failures)

            stallMainThread(until: { !self.samples.isEmpty })

            XCTAssertEqual(backtracer.calls, failures + 1)
            XCTAssertEqual(samples.count, 1, "the retry that succeeded should be the episode's only sample")
            XCTAssertEqual(samples.first?.backtrace.threads.first?.callstack.addresses, [ScriptedBacktracer.fakeFrame])
        }

        @MainActor
        func test_emptyCaptures_stopAfterMaxAttemptsPerEpisode() throws {
            let maxAttempts = StallTriggeredSampler.maxCaptureAttemptsPerEpisode
            try givenSampler(failingCaptures: .max)

            stallMainThread(until: { self.backtracer.calls >= maxAttempts }, extraPolls: 10)

            XCTAssertEqual(backtracer.calls, maxAttempts, "no capture should be attempted past the cap")
            XCTAssertTrue(samples.isEmpty, "empty captures must not be buffered")
        }

        @MainActor
        func test_attemptCap_resetsOnNewEpisode() throws {
            let maxAttempts = StallTriggeredSampler.maxCaptureAttemptsPerEpisode
            try givenSampler(failingCaptures: .max)

            stallMainThread(until: { self.backtracer.calls >= maxAttempts })
            stallMainThread(until: { self.backtracer.calls >= maxAttempts * 2 }, extraPolls: 10)

            XCTAssertEqual(backtracer.calls, maxAttempts * 2, "each episode gets its own attempts")
            XCTAssertTrue(samples.isEmpty)
        }
    }

#endif
