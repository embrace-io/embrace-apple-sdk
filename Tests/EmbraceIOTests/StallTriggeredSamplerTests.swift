//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import TestSupport
    import XCTest

    @testable import EmbraceCore
    @testable import EmbraceIO

    /// Blocks the calling thread for `seconds`. `@inline(never)` + a distinctive name so it is
    /// identifiable in a suspended-thread backtrace.
    @inline(never)
    private func embSamplerBlockingWork(seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    final class StallTriggeredSamplerTests: XCTestCase {

        override class func setUp() {
            super.setUp()
            _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp")).start()
        }

        override class func tearDown() {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            super.tearDown()
        }

        /// Runs `body` on the main queue (blocking main) while pumping the main run loop, so the
        /// beacon sees a busy epoch and the background sampler can walk main mid-block.
        @MainActor
        private func blockMainThread(for seconds: TimeInterval) {
            let done = expectation(description: "main unblocked")
            DispatchQueue.main.async {
                embSamplerBlockingWork(seconds: seconds)
                done.fulfill()
            }
            wait(for: [done], timeout: seconds + 5)
        }

        @MainActor
        func test_capturesOneDuringBlockSample_withBlockingWorkOnStack() throws {
            try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

            let sampler = StallTriggeredSampler(
                mainThread: pthread_self(),  // XCTest runs this on the main thread
                triggerThreshold: 0.05,
                pollInterval: 0.02,
                logger: nil
            )
            sampler.start()
            defer { sampler.stop() }

            blockMainThread(for: 0.3)

            let samples = sampler.samples(in: 0...UInt64.max)

            // Exactly one snapshot for the single stall episode (poller samples once per epoch).
            XCTAssertEqual(samples.count, 1, "expected exactly one during-block sample per stall episode")

            let names =
                samples.first?.backtrace.threads.first?.callstack
                .frames(symbolicated: true).compactMap { $0.symbol?.name } ?? []
            XCTAssertTrue(
                names.contains { $0.contains("embSamplerBlockingWork") },
                "during-block sample did not capture the blocking work; names: \(names.prefix(12))"
            )
        }

        func test_belowFloorValuesAreClampedUp() {
            // A hostile/bad remote config: both below the compiled-in floors.
            let sampler = StallTriggeredSampler(
                mainThread: pthread_self(),
                triggerThreshold: 0.001,
                pollInterval: 0.0001,
                logger: nil
            )
            XCTAssertEqual(sampler.effectiveTriggerThreshold, StallTriggeredSampler.minTriggerThreshold, accuracy: 1e-9)
            XCTAssertEqual(sampler.effectivePollInterval, StallTriggeredSampler.minPollInterval, accuracy: 1e-9)
        }

        func test_aboveFloorValuesArePreserved() {
            let sampler = StallTriggeredSampler(
                mainThread: pthread_self(),
                triggerThreshold: 0.2,
                pollInterval: 0.03,
                logger: nil
            )
            XCTAssertEqual(sampler.effectiveTriggerThreshold, 0.2, accuracy: 1e-6)
            XCTAssertEqual(sampler.effectivePollInterval, 0.03, accuracy: 1e-6)
        }

        @MainActor
        func test_pauseSuppressesSampling_thenResumeReArms() throws {
            try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

            let sampler = StallTriggeredSampler(
                mainThread: pthread_self(),
                triggerThreshold: 0.05,
                pollInterval: 0.02,
                logger: nil
            )
            sampler.start()
            defer { sampler.stop() }

            sampler.pause()
            blockMainThread(for: 0.3)
            XCTAssertEqual(sampler.samples(in: 0...UInt64.max).count, 0, "pause() should suppress sampling")

            sampler.resume()
            blockMainThread(for: 0.3)
            XCTAssertEqual(sampler.samples(in: 0...UInt64.max).count, 1, "resume() should re-arm sampling")
        }
    }

#endif
