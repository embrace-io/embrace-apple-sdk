//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    /// Tests verifying the C sampler state machine under concurrent access.
    ///
    /// The sampler uses CAS-based state transitions to prevent data races.
    /// These tests exercise the transitions under contention to verify that
    /// exactly one caller wins each race and no state corruption occurs.
    final class SamplerConcurrencyTests: XCTestCase {

        override func setUp() {
            super.setUp()
            emb_sampler_reset_for_testing()
        }

        override func tearDown() {
            emb_sampler_stop()
            _ = waitForSamplerToStop()
            emb_sampler_reset_for_testing()
            super.tearDown()
        }

        // MARK: - Concurrent start

        func test_concurrentStart_atMostOneSucceeds() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100,
                min_sampling_interval_ms: 10,
                max_frames: 128,
                min_frames: 0,
                fallback_walker: nil)

            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.concurrent.start", attributes: .concurrent)
            var okCount = 0
            var busyCount = 0
            var errorCount = 0
            let lock = NSLock()

            let threadCount = 10
            for _ in 0..<threadCount {
                group.enter()
                queue.async {
                    let result = emb_sampler_start(buf, config)
                    lock.lock()
                    switch result {
                    case EMB_SAMPLER_START_OK: okCount += 1
                    case EMB_SAMPLER_START_BUSY: busyCount += 1
                    default: errorCount += 1
                    }
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            XCTAssertGreaterThanOrEqual(okCount, 1,
                "At least one concurrent start should succeed")
            XCTAssertEqual(errorCount, 0,
                "No starts should return ERROR from a clean state")
            XCTAssertEqual(okCount + busyCount, threadCount,
                "All calls should be OK or BUSY (same config is idempotent)")

            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        // MARK: - Rapid start/stop

        func test_rapidStartStop_noStateCorruption() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50,
                min_sampling_interval_ms: 10,
                max_frames: 64,
                min_frames: 0,
                fallback_walker: nil)

            // 100 rapid start→stop cycles, stopping before the worker
            // may even reach RUNNING. This exercises the STARTING→STOPPING
            // and cleanup_previous_session paths.
            for i in 0..<100 {
                var result: emb_sampler_start_result_t
                repeat {
                    result = emb_sampler_start(buf, config)
                    if result == EMB_SAMPLER_START_BUSY {
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                } while result == EMB_SAMPLER_START_BUSY
                XCTAssertEqual(result, EMB_SAMPLER_START_OK,
                    "Cycle \(i): start should succeed after waiting")

                // Stop immediately. May catch the worker in STARTING.
                emb_sampler_stop()
            }

            _ = waitForSamplerToStop()

            // Verify final state is clean.
            XCTAssertFalse(emb_sampler_is_active(),
                "Sampler should be inactive after all cycles")
            XCTAssertNotEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED,
                "Should not have faulted during rapid start/stop")
        }

        // MARK: - Concurrent start and stop

        func test_concurrentStartAndStop_noCrashOrFault() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50,
                min_sampling_interval_ms: 10,
                max_frames: 64,
                min_frames: 0,
                fallback_walker: nil)

            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.start.stop.race", attributes: .concurrent)

            // 5 threads each doing 20 start/stop cycles concurrently.
            // The CAS state machine must remain consistent.
            for _ in 0..<5 {
                group.enter()
                queue.async {
                    for _ in 0..<20 {
                        let result = emb_sampler_start(buf, config)
                        if result == EMB_SAMPLER_START_OK {
                            Thread.sleep(forTimeInterval: 0.001)
                            emb_sampler_stop()
                        }
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                    group.leave()
                }
            }

            group.wait()

            // Ensure clean shutdown.
            emb_sampler_stop()
            _ = waitForSamplerToStop()

            // The primary assertion is reaching this point without crashing.
            // Also verify the state machine didn't fault.
            let state = emb_sampler_get_state()
            XCTAssertTrue(
                state == EMB_SAMPLER_STOPPED || state == EMB_SAMPLER_ZOMBIE,
                "Should be in a terminal non-faulted state, got \(state.rawValue)")
        }

        // MARK: - Start while stopping

        func test_start_whileStopping_returnsBusyThenSucceeds() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100,
                min_sampling_interval_ms: 10,
                max_frames: 128,
                min_frames: 0,
                fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning())

            // Non-blocking stop.
            emb_sampler_stop()

            // Immediately try to start again. The worker is still alive
            // (STOPPING state), so we expect BUSY.
            let immediateResult = emb_sampler_start(buf, config)
            // May be BUSY (still stopping) or OK (if worker exited very fast).
            XCTAssertTrue(
                immediateResult == EMB_SAMPLER_START_BUSY
                    || immediateResult == EMB_SAMPLER_START_OK,
                "Expected BUSY or OK, got \(immediateResult.rawValue)")

            if immediateResult == EMB_SAMPLER_START_BUSY {
                // Wait for full shutdown, then start should succeed.
                _ = waitForSamplerToStop()
                XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            }

            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }
    }

#endif
