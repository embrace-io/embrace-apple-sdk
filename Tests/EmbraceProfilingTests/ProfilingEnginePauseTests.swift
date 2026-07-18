//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    @testable import EmbraceProfiling
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    final class ProfilingEnginePauseTests: XCTestCase {

        // MARK: - Helpers

        private var engine: ProfilingEngine { ProfilingEngine.shared }

        private func waitForCapturing(
            _ expected: Bool,
            timeout: TimeInterval = 2.0
        ) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while engine.isCapturing != expected {
                if Date() >= deadline { return false }
                Thread.sleep(forTimeInterval: 0.001)
            }
            return true
        }

        /// Wait until the C sampler has fully exited (state is no longer active).
        /// `waitForCapturing(false)` succeeds the moment isCapturing flips false,
        /// which can be true while paused — use this when we want to wait for the
        /// worker thread to actually exit (e.g. after stop-from-paused).
        private func waitForFullStop(timeout: TimeInterval = 2.0) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while emb_sampler_is_active() {
                if Date() >= deadline { return false }
                Thread.sleep(forTimeInterval: 0.001)
            }
            return true
        }

        /// Configuration used throughout: 50ms cadence with 5ms drift floor.
        /// Fast enough for tests to observe sample growth in a few hundred ms,
        /// slow enough that pause observation latency (one cycle) is measurable.
        private static let fastConfig = ProfilingConfiguration(
            samplingIntervalMs: 50, minSamplingIntervalMs: 5)

        private func currentSampleCount() -> Int {
            switch engine.retrieveSamples(from: 0, through: UInt64.max) {
            case .success(let pr): return pr.samples.count
            default: return -1
            }
        }

        override func setUp() {
            super.setUp()
            engine.resetForTesting()
        }

        override func tearDown() {
            engine.resetForTesting()
            super.tearDown()
        }

        // MARK: - Default state

        func test_isPaused_falseByDefault() {
            XCTAssertFalse(engine.isPaused)
        }

        func test_pause_beforeStart_returnsFalse() {
            XCTAssertFalse(engine.pause())
        }

        func test_resume_beforeStart_returnsFalse() {
            XCTAssertFalse(engine.resume())
        }

        // MARK: - Basic pause/resume

        func test_pause_whileCapturing_setsIsPaused() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            XCTAssertFalse(engine.isPaused)

            XCTAssertTrue(engine.pause())
            XCTAssertTrue(engine.isPaused)
            XCTAssertFalse(engine.isCapturing,
                "isCapturing must be false while paused")
            XCTAssertTrue(engine.isActive,
                "isActive must remain true while paused (worker still alive)")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_resume_clearsIsPaused() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            XCTAssertTrue(engine.pause())
            XCTAssertTrue(engine.isPaused)

            XCTAssertTrue(engine.resume())
            XCTAssertFalse(engine.isPaused)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_pause_isIdempotent() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            XCTAssertTrue(engine.pause())
            XCTAssertTrue(engine.pause())  // Second call still returns true.
            XCTAssertTrue(engine.isPaused)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_resume_isIdempotent() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            XCTAssertTrue(engine.resume())  // Already not paused.
            XCTAssertTrue(engine.resume())
            XCTAssertFalse(engine.isPaused)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: - Sample growth

        func test_pause_stopsSampleGrowth() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            // Let samples accumulate.
            Thread.sleep(forTimeInterval: 0.15)
            XCTAssertTrue(engine.pause())

            // Wait one cycle for the worker to observe the pause flag, then
            // freeze a baseline.
            Thread.sleep(forTimeInterval: 0.1)
            let baseline = currentSampleCount()
            XCTAssertGreaterThan(baseline, 0,
                "Expected samples to have accumulated before pause")

            // After more time, sample count must not have grown.
            Thread.sleep(forTimeInterval: 0.2)
            let afterPause = currentSampleCount()
            XCTAssertEqual(afterPause, baseline,
                "Sample count must not grow while paused")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_resume_resumesSampleGrowth() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            XCTAssertTrue(engine.pause())
            Thread.sleep(forTimeInterval: 0.1)
            let beforeResume = currentSampleCount()

            XCTAssertTrue(engine.resume())
            Thread.sleep(forTimeInterval: 0.2)
            let afterResume = currentSampleCount()

            XCTAssertGreaterThan(afterResume, beforeResume,
                "Sample count must grow after resume")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_multiplePauseResumeCycles_workCorrectly() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            for _ in 0..<5 {
                XCTAssertTrue(engine.pause())
                XCTAssertTrue(engine.isPaused)
                Thread.sleep(forTimeInterval: 0.05)

                XCTAssertTrue(engine.resume())
                XCTAssertFalse(engine.isPaused)
                Thread.sleep(forTimeInterval: 0.05)
            }

            // After all cycles, sampling should still be functional.
            let countA = currentSampleCount()
            Thread.sleep(forTimeInterval: 0.1)
            let countB = currentSampleCount()
            XCTAssertGreaterThan(countB, countA,
                "Sampling should continue after repeated pause/resume cycles")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: - Pause-during-STARTING window

        func test_pause_immediatelyAfterStart_takesEffect() {
            // Synchronous start() then pause(): the worker is likely still in
            // STARTING when pause() runs. Pre-fix this returned false (pause
            // only accepted RUNNING) and the engine emitted samples until the
            // caller noticed and re-issued pause. With the C1 fix, pause()
            // accepts STARTING and takes effect from the worker's next loop
            // iteration onward.
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(engine.pause(),
                "pause() called immediately after start() must succeed even"
                + " when the worker is still in STARTING")

            Thread.sleep(forTimeInterval: 0.25)
            XCTAssertTrue(engine.isPaused)
            XCTAssertFalse(engine.isCapturing)

            // The worker samples immediately on reaching RUNNING (the cadence sleep is at the
            // end of its loop), so it can win the race against this pause() and land exactly
            // one sample. That is inherent to starting unpaused and is not what this test
            // pins down — `startPaused: true` is the race-free way to begin at zero, covered
            // by test_resume_immediatelyAfterStartPaused_takesEffect. What must hold here is
            // that pause() is honoured rather than lost: at a 50ms cadence the 0.25s above
            // would have produced ~5 samples if it were.
            let afterPause = currentSampleCount()
            XCTAssertLessThanOrEqual(afterPause, 1,
                "at most the single immediate sample may precede pause()")

            Thread.sleep(forTimeInterval: 0.25)
            XCTAssertEqual(currentSampleCount(), afterPause,
                "pause() applied during STARTING must stop all further sampling")

            engine.stop()
            XCTAssertTrue(waitForFullStop())
        }

        func test_resume_immediatelyAfterStartPaused_takesEffect() {
            // Symmetric companion: start with startPaused: true, then call
            // resume() synchronously. Without the C1 widening, resume would
            // return false and the engine would stay paused indefinitely.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 5,
                startPaused: true)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(engine.resume(),
                "resume() called immediately after start(startPaused:) must"
                + " succeed even when the worker is still in STARTING")

            Thread.sleep(forTimeInterval: 0.25)
            XCTAssertFalse(engine.isPaused)
            XCTAssertGreaterThan(currentSampleCount(), 0,
                "Samples should accumulate: resume was applied during STARTING")

            engine.stop()
            XCTAssertTrue(waitForFullStop())
        }

        // MARK: - startPaused config

        func test_startPaused_isPausedAndNotCapturing() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 5,
                startPaused: true)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(engine.isPaused,
                "Pause flag is set in start() before pthread_create, so it's"
                + " observable as soon as start returns")

            // Wait long enough for many sample cycles to confirm none happen.
            Thread.sleep(forTimeInterval: 0.25)

            XCTAssertEqual(currentSampleCount(), 0,
                "No samples should have been written while start-paused")
            XCTAssertFalse(engine.isCapturing,
                "isCapturing must be false while paused, even after start")
            XCTAssertTrue(engine.isActive,
                "isActive must be true (worker thread is alive)")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_startPaused_resumeCaptures() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 5,
                startPaused: true)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(engine.isPaused)
            XCTAssertEqual(currentSampleCount(), 0)

            XCTAssertTrue(engine.resume())
            Thread.sleep(forTimeInterval: 0.2)

            XCTAssertGreaterThan(currentSampleCount(), 0,
                "Samples should accumulate after resume from start-paused")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: - Buffer persistence across pause

        func test_buffer_persistsAcrossPause() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            Thread.sleep(forTimeInterval: 0.15)

            // Pause first, then settle and snapshot the count: this avoids a
            // race where a sample lands between a pre-pause read and pause().
            XCTAssertTrue(engine.pause())
            Thread.sleep(forTimeInterval: 0.1)

            let baseline = currentSampleCount()
            XCTAssertGreaterThan(baseline, 0,
                "Expected samples to have accumulated before pause")

            // The same samples remain readable on a subsequent retrieve.
            let secondRead = currentSampleCount()
            XCTAssertEqual(secondRead, baseline,
                "Existing samples must remain readable while paused")

            XCTAssertTrue(engine.resume())
            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: - Stop while paused

        func test_stop_whilePaused_cleansUpCleanly() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            XCTAssertTrue(engine.pause())

            engine.stop()
            XCTAssertTrue(waitForFullStop(),
                "Worker thread should fully exit even when stopped from paused")

            // Samples should still be retrievable after stop-from-paused.
            switch engine.retrieveSamples(from: 0, through: UInt64.max) {
            case .success: break
            default: XCTFail("retrieveSamples should succeed after stop-from-paused")
            }
        }

        func test_isPaused_falseAfterStop() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            XCTAssertTrue(engine.pause())
            XCTAssertTrue(engine.isPaused)

            engine.stop()
            XCTAssertTrue(waitForFullStop())

            // The Swift wrapper gates isPaused on RUNNING || STARTING, so a
            // residual flag value on a stopped engine must not leak through.
            XCTAssertFalse(engine.isPaused,
                "isPaused must return false on a stopped engine, even if the"
                + " underlying flag was set before stop")
        }

        func test_isPaused_clearedAfterRestart() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            XCTAssertTrue(engine.pause())
            XCTAssertTrue(engine.isPaused)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            // Wait for full stop so we can restart.
            while emb_sampler_is_active() {
                Thread.sleep(forTimeInterval: 0.001)
            }

            // Restart with default (non-paused) config.
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))
            XCTAssertFalse(engine.isPaused,
                "Pause flag should reset to start_paused config value on restart")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: - Concurrency

        func test_pauseResume_fromBackgroundThread() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            let expectation = expectation(description: "pause/resume from background")
            DispatchQueue.global().async {
                XCTAssertTrue(self.engine.pause())
                XCTAssertTrue(self.engine.isPaused)
                XCTAssertTrue(self.engine.resume())
                XCTAssertFalse(self.engine.isPaused)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_concurrentPauseResume_doesNotFault() {
            XCTAssertEqual(engine.start(configuration: Self.fastConfig), .started)
            XCTAssertTrue(waitForCapturing(true))

            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.pause.concurrent", attributes: .concurrent)

            let iterations = 200
            for _ in 0..<iterations {
                group.enter()
                queue.async {
                    _ = self.engine.pause()
                    group.leave()
                }
                group.enter()
                queue.async {
                    _ = self.engine.resume()
                    group.leave()
                }
            }
            group.wait()

            XCTAssertFalse(engine.isFaulted,
                "Concurrent pause/resume must not fault the engine")

            // Settle on a known state and verify the engine still samples.
            XCTAssertTrue(engine.resume())
            Thread.sleep(forTimeInterval: 0.1)
            XCTAssertGreaterThan(currentSampleCount(), 0,
                "Sampling should be functional after concurrent pause/resume churn")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }
    }

#endif
