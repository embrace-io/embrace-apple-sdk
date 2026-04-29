//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    final class SamplerTests: XCTestCase {

        // MARK: - Helpers

        /// Create a ring buffer suitable for testing. Caller must destroy.
        private func makeBuffer() -> UnsafeMutablePointer<emb_ring_buffer_t> {
            let buf = emb_ring_buffer_create(1024 * 1024)
            XCTAssertNotNil(buf)
            return buf!
        }

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

        // MARK: - Validation tests

        func test_start_withNullBuffer_returnsFalse() {
            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(nil, config), EMB_SAMPLER_START_ERROR)
        }

        func test_start_withZeroInterval_returnsFalse() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 0, min_sampling_interval_ms: 0,
                max_frames: 128, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_ERROR)
        }

        func test_start_withZeroMaxFrames_returnsFalse() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 0, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_ERROR)
        }

        func test_start_minIntervalExceedsInterval_returnsError() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 200,
                max_frames: 128, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_ERROR)
        }

        func test_start_zeroMinInterval_returnsError() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 0,
                max_frames: 128, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_ERROR)
        }

        func test_start_maxFramesExceedingLimit_clamps() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // C layer clamps max_frames to EMB_MAX_STACK_FRAMES (1024).
            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 2000, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)

            // Stop before defer destroys the buffer while the worker is still running.
            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        // MARK: - Lifecycle tests

        func test_startStop_lifecycle() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertFalse(emb_sampler_is_active())

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(emb_sampler_is_active())

            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())
            XCTAssertFalse(emb_sampler_is_active())
        }

        func test_start_whenAlreadyRunning_sameConfig_returnsOK() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning(),
                "Sampler should reach RUNNING state")

            // Idempotent: same config+buffer returns OK.
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(emb_sampler_is_active())

            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        func test_start_whenAlreadyRunning_differentConfig_returnsConfigMismatch() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning(),
                "Sampler should reach RUNNING state")

            // Different config returns CONFIG_MISMATCH.
            let otherConfig = emb_sampler_config_t(
                sampling_interval_ms: 200, min_sampling_interval_ms: 20,
                max_frames: 64, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, otherConfig), EMB_SAMPLER_START_CONFIG_MISMATCH)

            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        func test_start_whenAlreadyRunning_differentBuffer_returnsConfigMismatch() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }
            let buf2 = makeBuffer()
            defer { emb_ring_buffer_destroy(buf2) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning(),
                "Sampler should reach RUNNING state")

            // Same config but different buffer returns CONFIG_MISMATCH.
            XCTAssertEqual(emb_sampler_start(buf2, config), EMB_SAMPLER_START_CONFIG_MISMATCH)

            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        func test_stop_whenNotRunning_isNoop() {
            // Stop without ever starting (should be a no-op).
            emb_sampler_stop()
            XCTAssertFalse(emb_sampler_is_active())
        }

        func test_isActive_zombieState_triggersCleanupToStopped() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning())

            emb_sampler_stop()

            // Wait for the worker thread to exit (ZOMBIE state).
            // Poll get_state() directly. Do NOT use is_active(), which
            // would trigger cleanup and hide the ZOMBIE state.
            let deadline = Date().addingTimeInterval(2.0)
            while emb_sampler_get_state() != EMB_SAMPLER_ZOMBIE {
                if Date() >= deadline { break }
                Thread.sleep(forTimeInterval: 0.001)
            }

            // The state should be ZOMBIE (worker exited, not yet reaped).
            // Note: On very fast machines the cleanup may have already been
            // triggered by a preceding is_active() call, so also accept STOPPED.
            let state = emb_sampler_get_state()
            XCTAssertTrue(
                state == EMB_SAMPLER_ZOMBIE || state == EMB_SAMPLER_STOPPED,
                "Expected ZOMBIE or STOPPED after stop, got \(state.rawValue)")

            if state == EMB_SAMPLER_ZOMBIE {
                // Now call is_active() which should trigger cleanup_previous_session.
                XCTAssertFalse(emb_sampler_is_active(),
                    "is_active() should return false after cleanup")
                XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_STOPPED,
                    "State should be STOPPED after is_active() cleans up ZOMBIE")
            }

            // Verify the sampler can restart cleanly after the cleanup.
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        func test_stop_duringStarting_transitionsCleanly() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            // Rapidly start then stop, trying to catch STARTING state.
            // The worker thread may be in STARTING when stop() is called,
            // exercising the STARTING→STOPPING→ZOMBIE path.
            for _ in 0..<50 {
                let result = emb_sampler_start(buf, config)
                if result == EMB_SAMPLER_START_BUSY {
                    _ = waitForSamplerToStop()
                    continue
                }
                XCTAssertEqual(result, EMB_SAMPLER_START_OK)

                // Stop immediately without waiting for RUNNING.
                emb_sampler_stop()
                _ = waitForSamplerToStop()

                // Verify clean state after each cycle.
                XCTAssertFalse(emb_sampler_is_active())
                XCTAssertNotEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED,
                    "Should not fault during STARTING→STOPPING transition")
            }
        }

        // MARK: - State query tests

        func test_getState_stoppedInitially() {
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_STOPPED)
        }

        func test_getState_runningAfterStart() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning())
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_RUNNING)

            // Stop before defer destroys the buffer while the worker is still running.
            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        // MARK: - Fault injection tests

        func test_injectFault_setsStateAndReason() {
            emb_sampler_inject_fault_for_testing("test fault")
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED)
            XCTAssertEqual(String(cString: emb_sampler_get_fault_reason()), "test fault")
        }

        func test_faultReason_nilWhenNotFaulted() {
            XCTAssertNil(emb_sampler_get_fault_reason())
        }

        func test_injectFault_withNilReason_setsNoReasonGiven() {
            emb_sampler_inject_fault_for_testing(nil)
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED)
            let reason = emb_sampler_get_fault_reason()
            XCTAssertNotNil(reason, "Fault reason should never be NULL")
            XCTAssertEqual(String(cString: reason!), "no reason given")
        }

        func test_start_whenFaulted_returnsError() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            emb_sampler_inject_fault_for_testing("injected")

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_ERROR)
        }

        func test_isActive_falseWhenFaulted() {
            emb_sampler_inject_fault_for_testing("injected")
            XCTAssertFalse(emb_sampler_is_active())
        }

        func test_threadSuspendFailure_causesFault() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // Set main thread to an invalid Mach port. When the worker tries
            // thread_suspend on this dead port, it will fail and fault.
            emb_sampler_set_main_thread_for_testing(mach_port_t(bitPattern: -1), pthread_self())
            defer {
                // Restore valid main thread info for subsequent tests.
                if pthread_main_np() != 0 {
                    let mainMach = pthread_mach_thread_np(pthread_self())
                    emb_sampler_set_main_thread_for_testing(mainMach, pthread_self())
                }
            }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)

            // Wait for the sampler to fault (worker hits thread_suspend failure).
            let deadline = Date().addingTimeInterval(2.0)
            while emb_sampler_get_state() != EMB_SAMPLER_FAULTED {
                if Date() >= deadline { break }
                Thread.sleep(forTimeInterval: 0.001)
            }

            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED,
                "Sampler should enter FAULTED state after thread_suspend fails")
            XCTAssertNotNil(emb_sampler_get_fault_reason(),
                "Fault reason should be set")

            // Attempting to restart should return ERROR.
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_ERROR,
                "Starting a faulted sampler should return ERROR")
        }

        func test_faulted_thenReset_thenStart_succeeds() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            emb_sampler_inject_fault_for_testing("injected")
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED)

            XCTAssertTrue(emb_sampler_reset_for_testing())
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_STOPPED)

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)

            // Stop before defer destroys the buffer while the worker is still running.
            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        // MARK: - Reset tests

        func test_resetForTesting_fromStopped_returnsTrue() {
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_STOPPED)
            XCTAssertTrue(emb_sampler_reset_for_testing())
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_STOPPED)
        }

        func test_resetForTesting_fromFaulted_returnsTrue() {
            emb_sampler_inject_fault_for_testing("injected")
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED)
            XCTAssertTrue(emb_sampler_reset_for_testing())
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_STOPPED)
        }

        func test_resetForTesting_whileRunning_returnsFalse() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            XCTAssertTrue(waitForSamplerRunning())

            XCTAssertFalse(emb_sampler_reset_for_testing())
            XCTAssertEqual(emb_sampler_get_state(), EMB_SAMPLER_RUNNING)

            // Stop before defer destroys the buffer while the worker is still running.
            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        // MARK: - Main thread override test

        func test_setMainThread_allowsSamplingTestThread() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // Create a test thread with a known stack depth.
            guard let testThread = emb_test_thread_create(20) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(testThread) }

            let port = emb_test_thread_get_port(testThread)
            let pth = pthread_from_mach_thread_np(port)
            emb_sampler_set_main_thread_for_testing(port, pth!)

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            Thread.sleep(forTimeInterval: 0.15)
            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())

            // Clear override before assertions (cleanup).
            emb_sampler_set_main_thread_for_testing(0, nil)

            let records = testReadRange(buf, 0, UInt64.max)
            XCTAssertGreaterThanOrEqual(records.count, 1,
                "Should have captured at least 1 sample from the test thread")
            for record in records {
                XCTAssertGreaterThan(record.frame_count, 0,
                    "Samples should contain frames from the test thread stack")
            }
        }

        // MARK: - Sampling verification

        func test_capturesSamplesAtExpectedRate() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // 10 Hz sampling → expect ~10 samples in 1 second.
            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)

            Thread.sleep(forTimeInterval: 1.0)

            emb_sampler_stop()
            _ = waitForSamplerToStop()

            // Read all samples from the ring buffer.
            let records = testReadRange(buf, 0, UInt64.max)

            // Expect ~10 samples, allow ±5 tolerance for CI robustness.
            XCTAssertGreaterThanOrEqual(records.count, 5,
                "Expected at least 5 samples at 10 Hz over 1s, got \(records.count)")
            XCTAssertLessThanOrEqual(records.count, 15,
                "Expected at most 15 samples at 10 Hz over 1s, got \(records.count)")
        }

        // MARK: - Stress / edge cases

        func test_repeatedStartStop_noLeaks() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50, min_sampling_interval_ms: 10,
                max_frames: 64, min_frames: 0, fallback_walker: nil)

            for _ in 0..<50 {
                // start() may return BUSY if the previous session is still
                // stopping. Poll until it succeeds.
                var result: emb_sampler_start_result_t
                repeat {
                    result = emb_sampler_start(buf, config)
                    if result == EMB_SAMPLER_START_BUSY {
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                } while result == EMB_SAMPLER_START_BUSY
                XCTAssertEqual(result, EMB_SAMPLER_START_OK)

                Thread.sleep(forTimeInterval: 0.01)
                emb_sampler_stop()
                XCTAssertTrue(waitForSamplerToStop())
            }
        }

        // MARK: - Long-running session

        func test_longRunningSession_noCorruption() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // Run at 20 Hz for 5 seconds → expect ~100 samples.
            let config = emb_sampler_config_t(
                sampling_interval_ms: 50, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            Thread.sleep(forTimeInterval: 5.0)
            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())

            let records = testReadRange(buf, 0, UInt64.max)

            // At 20 Hz for 5s, expect ~100 samples. Allow wide tolerance for CI.
            XCTAssertGreaterThanOrEqual(records.count, 50,
                "Expected at least 50 samples at 20 Hz over 5s, got \(records.count)")

            // Timestamps must be strictly increasing.
            for i in 1..<records.count {
                XCTAssertGreaterThan(
                    records[i].timestamp_ns,
                    records[i - 1].timestamp_ns,
                    "Timestamps must be strictly increasing at index \(i)")
            }

            // Every sample must have at least one frame.
            for (i, record) in records.enumerated() {
                XCTAssertGreaterThan(record.frame_count, 0,
                    "Sample \(i) should have at least one frame")
            }

            // Verify the sampler didn't fault during the long run.
            XCTAssertNotEqual(emb_sampler_get_state(), EMB_SAMPLER_FAULTED,
                "Sampler should not fault during a long-running session")
        }

        // MARK: - Multiple start/collect/stop cycles

        func test_multipleStartCollectStopCycles() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            for cycle in 0..<5 {
                // Reset the ring buffer between cycles so each starts clean.
                XCTAssertTrue(emb_ring_buffer_reset(buf),
                    "Cycle \(cycle): buffer reset should succeed")

                // Start, run, stop.
                var result: emb_sampler_start_result_t
                repeat {
                    result = emb_sampler_start(buf, config)
                    if result == EMB_SAMPLER_START_BUSY {
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                } while result == EMB_SAMPLER_START_BUSY
                XCTAssertEqual(result, EMB_SAMPLER_START_OK,
                    "Cycle \(cycle): start should succeed")

                Thread.sleep(forTimeInterval: 0.2)
                emb_sampler_stop()
                XCTAssertTrue(waitForSamplerToStop(),
                    "Cycle \(cycle): stop should complete")

                // Collect and verify.
                let records = testReadRange(buf, 0, UInt64.max)
                XCTAssertGreaterThan(records.count, 0,
                    "Cycle \(cycle): should have captured samples")

                for i in 1..<records.count {
                    XCTAssertGreaterThan(
                        records[i].timestamp_ns,
                        records[i - 1].timestamp_ns,
                        "Cycle \(cycle): timestamps must increase at index \(i)")
                }
            }
        }

        // MARK: - Main thread resolution

        func test_start_afterCacheClear_resolvesFromMainThread() {
            // This test verifies that emb_sampler_start can re-resolve
            // main thread info after the cache is cleared.
            // Only meaningful when running on the main thread.
            guard pthread_main_np() != 0 else {
                // Not on main thread; skip (some test runners use background threads).
                return
            }

            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // Clear the cached main thread info.
            emb_sampler_set_main_thread_for_testing(0, nil)
            defer {
                // Restore: re-cache from main thread so subsequent tests work.
                if pthread_main_np() != 0 {
                    let mainMach = pthread_mach_thread_np(pthread_self())
                    emb_sampler_set_main_thread_for_testing(mainMach, pthread_self())
                }
            }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            // Start from main thread should re-resolve and succeed.
            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)

            emb_sampler_stop()
            _ = waitForSamplerToStop()
        }

        func test_start_fromNonMainThread_withoutCache_returnsError() {
            let buf = makeBuffer()
            defer { emb_ring_buffer_destroy(buf) }

            // Clear the cached main thread info.
            emb_sampler_set_main_thread_for_testing(0, nil)
            defer {
                // Restore cache for subsequent tests.
                if pthread_main_np() != 0 {
                    let mainMach = pthread_mach_thread_np(pthread_self())
                    emb_sampler_set_main_thread_for_testing(mainMach, pthread_self())
                }
            }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 100, min_sampling_interval_ms: 10,
                max_frames: 128, min_frames: 0, fallback_walker: nil)

            // Start from a background thread without cache should fail.
            let group = DispatchGroup()
            var bgResult: emb_sampler_start_result_t = EMB_SAMPLER_START_OK
            group.enter()
            DispatchQueue.global().async {
                bgResult = emb_sampler_start(buf, config)
                group.leave()
            }
            group.wait()

            XCTAssertEqual(bgResult, EMB_SAMPLER_START_ERROR,
                "Start from non-main thread without cached main thread should fail")
        }
    }

#endif
