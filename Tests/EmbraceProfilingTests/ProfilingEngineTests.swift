//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    @testable import EmbraceProfiling
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    final class ProfilingEngineTests: XCTestCase {

        // MARK: - Helpers

        private var engine: ProfilingEngine { ProfilingEngine.shared }

        /// Poll until `isCapturing` becomes the expected value, or time out.
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

        /// Poll until `emb_sampler_is_active()` returns false, or time out.
        /// Unlike `waitForCapturing(false)`, this waits for STOPPING/ZOMBIE
        /// cleanup to complete (required before restarting the sampler).
        private func waitForFullStop(timeout: TimeInterval = 2.0) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while emb_sampler_is_active() {
                if Date() >= deadline { return false }
                Thread.sleep(forTimeInterval: 0.001)
            }
            return true
        }

        override func setUp() {
            super.setUp()
            engine.resetForTesting()
        }

        override func tearDown() {
            engine.resetForTesting()
            super.tearDown()
        }

        // MARK: Configuration Validation

        func test_start_withDefaultConfig_returnsStarted() {
            let result = engine.start()
            XCTAssertEqual(result, .started)
            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_start_zeroInterval_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(samplingIntervalMs: 0)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        func test_start_zeroMinInterval_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(minSamplingIntervalMs: 0)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        func test_start_minExceedsInterval_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 100)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        func test_start_zeroMaxFrames_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(maxFramesPerSample: 0)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        func test_start_zeroBufferCapacity_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(bufferCapacityBytes: 0)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        func test_start_maxFramesExceedsLimit_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(maxFramesPerSample: 1025)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        func test_start_bufferCapacityExceedsLimit_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(bufferCapacityBytes: 10_485_761) // 10 MB + 1
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        // MARK: Lifecycle

        func test_isCapturing_falseBeforeStart() {
            XCTAssertFalse(engine.isCapturing)
        }

        func test_start_stop_lifecycle() {
            let result = engine.start()
            XCTAssertEqual(result, .started)
            XCTAssertTrue(waitForCapturing(true),
                "Engine should reach capturing state")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false),
                "Engine should stop capturing")
        }

        func test_start_whileRunning_returnsAlreadyActive() {
            XCTAssertEqual(engine.start(), .started)
            XCTAssertTrue(waitForCapturing(true))

            XCTAssertEqual(engine.start(), .alreadyActive)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_stop_whenNotRunning_isNoop() {
            // Should not crash or produce errors.
            engine.stop()
            XCTAssertFalse(engine.isCapturing)
        }

        // MARK: Fault Injection

        func test_isFaulted_falseByDefault() {
            XCTAssertFalse(engine.isFaulted)
            XCTAssertNil(engine.faultReason)
        }

        func test_start_whenFaulted_returnsFaultedWithReason() {
            _injectFault("test engine fault")

            let result = engine.start()
            if case .faulted(let reason) = result {
                XCTAssertEqual(reason, "test engine fault")
            } else {
                XCTFail("Expected .faulted, got \(result)")
            }
        }

        func test_retrieveSamples_whenFaulted_returnsFaulted() {
            XCTAssertTrue(engine.allocateBufferForTesting())
            engine.resetForTesting()
            // Re-allocate after reset (reset destroys the buffer).
            XCTAssertTrue(engine.allocateBufferForTesting())

            _injectFault("retrieve fault test")

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            if case .faulted(let reason) = result {
                XCTAssertEqual(reason, "retrieve fault test")
            } else {
                XCTFail("Expected .faulted, got \(result)")
            }
        }

        func test_resetForTesting_clearsFaultedState() {
            _injectFault("to be cleared")
            XCTAssertTrue(engine.isFaulted)

            engine.resetForTesting()

            XCTAssertFalse(engine.isFaulted)
            XCTAssertNil(engine.faultReason)

            let result = engine.start()
            XCTAssertEqual(result, .started)
            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: Deterministic Sample Write/Retrieve

        func test_allocateBufferForTesting_succeeds() {
            XCTAssertTrue(engine.allocateBufferForTesting())
        }

        func test_allocateBufferForTesting_invalidConfig_returnsFalse() {
            let config = ProfilingConfiguration(samplingIntervalMs: 0)
            XCTAssertFalse(engine.allocateBufferForTesting(configuration: config))
        }

        func test_writeSample_withoutBuffer_returnsFalse() {
            // No buffer allocated. Write should fail.
            XCTAssertFalse(engine.writeSampleForTesting(
                timestamp: 1000, frames: [0x1000, 0x2000]))
        }

        func test_writeSamples_thenRetrieve_roundtrips() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            let testSamples: [(ts: UInt64, frames: [UInt])] = [
                (100, [0xAAAA, 0xBBBB, 0xCCCC]),
                (200, [0x1111, 0x2222]),
                (300, [0xDEAD, 0xBEEF, 0xCAFE, 0xBABE]),
            ]

            for sample in testSamples {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: sample.ts, frames: sample.frames))
            }

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let profilingResult) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertEqual(profilingResult.samples.count, 3)

            for (i, sample) in profilingResult.samples.enumerated() {
                XCTAssertEqual(sample.timestamp, testSamples[i].ts)
                let frames = profilingResult.frames(for: sample)
                XCTAssertEqual(Array(frames), testSamples[i].frames,
                    "Frames for sample \(i) should round-trip")
            }
        }

        func test_retrieveSamples_timeRangeFiltering() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            for ts: UInt64 in [100, 200, 300, 400, 500] {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: ts, frames: [UInt(ts)]))
            }

            // Retrieve only timestamps 200..400.
            let result = engine.retrieveSamples(from: 200, through: 400)
            guard case .success(let profilingResult) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertEqual(profilingResult.samples.count, 3,
                "Should return samples with timestamps 200, 300, 400")
            XCTAssertEqual(profilingResult.samples[0].timestamp, 200)
            XCTAssertEqual(profilingResult.samples[1].timestamp, 300)
            XCTAssertEqual(profilingResult.samples[2].timestamp, 400)
        }

        func test_retrieveSamples_beforeStart_returnsNotStarted() {
            // No buffer, no start. Should return notStarted.
            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            if case .notStarted = result {
                // expected
            } else {
                XCTFail("Expected .notStarted, got \(result)")
            }
        }

        func test_retrieveSamples_framesAccessor_returnsCorrectSlice() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            // Write samples with varying frame counts.
            let framesA: [UInt] = [0xA1, 0xA2]
            let framesB: [UInt] = [0xB1, 0xB2, 0xB3, 0xB4, 0xB5]
            let framesC: [UInt] = [0xC1]

            XCTAssertTrue(engine.writeSampleForTesting(timestamp: 10, frames: framesA))
            XCTAssertTrue(engine.writeSampleForTesting(timestamp: 20, frames: framesB))
            XCTAssertTrue(engine.writeSampleForTesting(timestamp: 30, frames: framesC))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertEqual(pr.samples.count, 3)
            XCTAssertEqual(Array(pr.frames(for: pr.samples[0])), framesA)
            XCTAssertEqual(Array(pr.frames(for: pr.samples[1])), framesB)
            XCTAssertEqual(Array(pr.frames(for: pr.samples[2])), framesC)
        }

        // MARK: Real Sampler Integration

        func test_realSampler_capturesSamples() {
            // Start at 20 Hz (50ms interval).
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)

            XCTAssertEqual(engine.start(configuration: config), .started)

            Thread.sleep(forTimeInterval: 0.25)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertGreaterThanOrEqual(pr.samples.count, 3,
                "Expected at least 3 samples at 20 Hz over 250ms, got \(pr.samples.count)")

            // Verify timestamps are strictly increasing.
            for i in 1..<pr.samples.count {
                XCTAssertGreaterThan(pr.samples[i].timestamp, pr.samples[i - 1].timestamp)
            }

            // Verify each sample has non-empty frames.
            for (i, sample) in pr.samples.enumerated() {
                let frames = pr.frames(for: sample)
                XCTAssertFalse(frames.isEmpty,
                    "Sample \(i) should have at least one frame")
            }
        }

        // MARK: Buffer Reuse & Resize

        func test_start_sameCapacity_clearsOldSamples() {
            // Allocate buffer and write synthetic data.
            XCTAssertTrue(engine.allocateBufferForTesting())
            XCTAssertTrue(engine.writeSampleForTesting(
                timestamp: 100, frames: [0xAAAA]))

            // Verify the synthetic data is readable.
            if case .success(let before) = engine.retrieveSamples(
                from: 100, through: 100)
            {
                XCTAssertEqual(before.samples.count, 1)
            }

            // Start with same default capacity (1MB). This resets the buffer.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)
            XCTAssertEqual(engine.start(configuration: config), .started)
            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            // The old synthetic sample (ts=100) should be gone.
            let result = engine.retrieveSamples(from: 100, through: 100)
            if case .success(let after) = result {
                XCTAssertEqual(after.samples.count, 0,
                    "Old samples should be cleared after restart with same capacity")
            }
        }

        func test_start_differentCapacity_succeeds() {
            let config1 = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10,
                bufferCapacityBytes: 1_048_576)
            let config2 = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10,
                bufferCapacityBytes: 2_097_152)

            // Start with capacity A.
            XCTAssertEqual(engine.start(configuration: config1), .started)
            engine.stop()
            XCTAssertTrue(waitForFullStop(),
                "Sampler must be fully inactive before restarting with different capacity")

            // Restart with capacity B (destroys old buffer, creates new).
            XCTAssertEqual(engine.start(configuration: config2), .started)
            XCTAssertTrue(waitForCapturing(true))

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_start_restartSameCapacity_succeeds() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)

            // First start.
            XCTAssertEqual(engine.start(configuration: config), .started)
            engine.stop()
            XCTAssertTrue(waitForFullStop(),
                "Sampler must be fully inactive before restarting")

            // Second start with same capacity (reuses buffer via reset).
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: Retrieve While Running

        func test_retrieveSamples_whileRunning_succeeds() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            // Let samples accumulate.
            Thread.sleep(forTimeInterval: 0.2)

            // Retrieve while the sampler is still actively writing.
            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success while running, got \(result)")
                engine.stop()
                _ = waitForCapturing(false)
                return
            }

            XCTAssertGreaterThan(pr.samples.count, 0,
                "Should capture samples while still running")

            // Timestamps should be in order.
            for i in 1..<pr.samples.count {
                XCTAssertGreaterThan(
                    pr.samples[i].timestamp,
                    pr.samples[i - 1].timestamp)
            }

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: Concurrent ProfilingEngine Access

        func test_concurrentStart_atMostOneSucceeds() {
            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.concurrent.start", attributes: .concurrent)
            var startedCount = 0
            var alreadyActiveCount = 0
            var operationInProgressCount = 0
            var otherCount = 0
            let lock = NSLock()

            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 10)

            let threadCount = 10
            for _ in 0..<threadCount {
                group.enter()
                queue.async {
                    let result = self.engine.start(configuration: config)
                    lock.lock()
                    switch result {
                    case .started: startedCount += 1
                    case .alreadyActive: alreadyActiveCount += 1
                    case .operationInProgress: operationInProgressCount += 1
                    default: otherCount += 1
                    }
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            XCTAssertLessThanOrEqual(startedCount, 1,
                "At most one concurrent start should succeed")
            XCTAssertEqual(
                startedCount + alreadyActiveCount + operationInProgressCount,
                threadCount,
                "All calls should be started/alreadyActive/operationInProgress"
                    + " (unexpected: \(otherCount))")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_concurrentRetrieveSamples_noCorruption() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            // Write deterministic samples.
            for ts: UInt64 in stride(from: 100, through: 1000, by: 100) {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: ts, frames: [UInt(ts)]))
            }

            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.concurrent.retrieve", attributes: .concurrent)
            var successCount = 0
            var busyCount = 0
            var corruptionCount = 0
            let lock = NSLock()

            let threadCount = 10
            for _ in 0..<threadCount {
                group.enter()
                queue.async {
                    let result = self.engine.retrieveSamples(
                        from: 0, through: UInt64.max)
                    lock.lock()
                    switch result {
                    case .success(let pr):
                        successCount += 1
                        // Verify data integrity for each successful read.
                        for sample in pr.samples {
                            let frames = pr.frames(for: sample)
                            if frames.count == 1 {
                                if frames.first != UInt(sample.timestamp) {
                                    corruptionCount += 1
                                    break
                                }
                            }
                        }
                    case .busy:
                        busyCount += 1
                    default:
                        break
                    }
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            // The gate serializes access, so most calls succeed sequentially.
            // Some may get .busy if the gate times out under heavy contention.
            XCTAssertGreaterThan(successCount, 0,
                "At least one concurrent retrieve should succeed")
            XCTAssertEqual(successCount + busyCount, threadCount,
                "All calls should return .success or .busy")
            XCTAssertEqual(corruptionCount, 0,
                "Frame data should match timestamps (no corruption)")
        }

        // MARK: Eviction Through ProfilingEngine

        func test_eviction_oldSamplesEvictedWhenBufferFills() {
            // Use the smallest valid buffer so eviction occurs quickly.
            let config = ProfilingConfiguration(bufferCapacityBytes: 131073)
            XCTAssertTrue(engine.allocateBufferForTesting(configuration: config))

            // Each record: header (16 bytes) + 10 frames × 8 bytes = 96 bytes.
            // 131073 / 96 ≈ 1365 records fit before eviction.
            let frames: [UInt] = (1...10).map { UInt($0) }
            let totalWrites = 2000

            for i in 0..<totalWrites {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: UInt64(i + 1) * 1000, frames: frames))
            }

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertGreaterThan(pr.samples.count, 0, "Should have surviving samples")
            XCTAssertLessThan(pr.samples.count, totalWrites,
                "Some samples should have been evicted")
            XCTAssertGreaterThan(pr.samples[0].timestamp, 1000,
                "Earliest samples should have been evicted")

            // All surviving samples should be ordered and have intact frames.
            for i in 1..<pr.samples.count {
                XCTAssertGreaterThan(pr.samples[i].timestamp,
                    pr.samples[i - 1].timestamp)
            }
            for sample in pr.samples {
                XCTAssertEqual(Array(pr.frames(for: sample)), frames,
                    "Frame data should survive eviction intact")
            }
        }

        // MARK: Concurrent Start + Retrieve

        func test_concurrentRetrieveWhileRunning_noCorruption() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 5)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            // Let some samples accumulate.
            Thread.sleep(forTimeInterval: 0.05)

            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.concurrent.retrieve.running",
                attributes: .concurrent)
            var corruptionCount = 0
            var successCount = 0
            let lock = NSLock()

            let iterations = 50
            for _ in 0..<iterations {
                group.enter()
                queue.async {
                    let result = self.engine.retrieveSamples(
                        from: 0, through: UInt64.max)
                    lock.lock()
                    if case .success(let pr) = result {
                        successCount += 1
                        // Verify timestamps are strictly ordered.
                        if pr.samples.count > 1 {
                            for i in 1..<pr.samples.count {
                                if pr.samples[i].timestamp
                                    <= pr.samples[i - 1].timestamp
                                {
                                    corruptionCount += 1
                                    break
                                }
                            }
                        }
                        // Verify frame ranges don't exceed the frames array.
                        for sample in pr.samples {
                            if sample.frameRange.upperBound > pr.frames.count {
                                corruptionCount += 1
                                break
                            }
                        }
                    }
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            XCTAssertGreaterThan(successCount, 0,
                "At least some concurrent retrieves should succeed")
            XCTAssertEqual(corruptionCount, 0,
                "No data corruption during concurrent retrieve while running")
        }

        // MARK: Start During Shutdown

        func test_start_immediatelyAfterStop_handlesGracefully() {
            // Start, then immediately stop + start again. The second start
            // should get either .started (if shutdown completed) or
            // .samplerBusy (if still shutting down). Never an error.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)

            for _ in 0..<20 {
                XCTAssertEqual(engine.start(configuration: config), .started)
                XCTAssertTrue(waitForCapturing(true))

                engine.stop()
                // Don't wait for full stop. Immediately try to start again.
                let result = engine.start(configuration: config)
                switch result {
                case .started, .samplerBusy, .operationInProgress, .alreadyActive:
                    break // All acceptable outcomes during shutdown race.
                default:
                    XCTFail("Unexpected result during shutdown race: \(result)")
                }

                // Clean up for next iteration.
                engine.stop()
                XCTAssertTrue(waitForCapturing(false))
                // Wait for full cleanup so next iteration starts clean.
                while emb_sampler_is_active() {
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        }

        // MARK: Configuration Boundary Values (valid edge)

        func test_start_maxFramesAtLimit_succeeds() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 10,
                maxFramesPerSample: 1024)
            XCTAssertEqual(engine.start(configuration: config), .started)
            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_start_bufferCapacityAtLimit_succeeds() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 10,
                bufferCapacityBytes: 10_485_760)  // Exactly 10 MB
            XCTAssertEqual(engine.start(configuration: config), .started)
            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        func test_start_minIntervalEqualsInterval_returnsInvalidConfiguration() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 50)
            XCTAssertEqual(engine.start(configuration: config), .invalidConfiguration)
        }

        // MARK: Empty Retrieve After Start

        func test_retrieveSamples_immediatelyAfterStart_returnsEmptySuccess() {
            // Start the engine but retrieve before any samples can accumulate.
            // This is the "startup profiling" pattern: start early, retrieve later.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 1000, minSamplingIntervalMs: 100)
            XCTAssertEqual(engine.start(configuration: config), .started)

            // Retrieve immediately. No time for samples to be written.
            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            switch result {
            case .success(let pr):
                // Empty or very few samples is acceptable; the key assertion
                // is that we get .success, not .notStarted or .busy.
                _ = pr
            default:
                XCTFail("Expected .success (possibly empty), got \(result)")
            }

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: Inverted Time Range

        func test_retrieveSamples_invertedTimeRange_returnsEmptySuccess() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            // Write some samples.
            for ts: UInt64 in [100, 200, 300, 400, 500] {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: ts, frames: [UInt(ts)]))
            }

            // Retrieve with start > end (inverted range).
            let result = engine.retrieveSamples(from: 500, through: 100)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }
            XCTAssertEqual(pr.samples.count, 0,
                "Inverted time range should return empty success")
        }

        // MARK: Samples Persist After Stop

        func test_retrieveSamples_persistAfterStop_multipleRetrievals() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            Thread.sleep(forTimeInterval: 0.2)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            // First retrieval after stop.
            let result1 = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr1) = result1 else {
                XCTFail("Expected .success, got \(result1)")
                return
            }
            XCTAssertGreaterThan(pr1.samples.count, 0,
                "Should have samples after stop")

            // Second retrieval. Samples should still be there.
            let result2 = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr2) = result2 else {
                XCTFail("Expected .success on second retrieve, got \(result2)")
                return
            }
            XCTAssertEqual(pr1.samples.count, pr2.samples.count,
                "Same samples should be returned on repeated retrieval")
            for i in 0..<pr1.samples.count {
                XCTAssertEqual(pr1.samples[i].timestamp, pr2.samples[i].timestamp,
                    "Timestamps should match between retrievals at index \(i)")
            }
        }

        // MARK: Three-Way Contention

        func test_concurrentStartStopRetrieve_noCorruption() {
            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.threeway", attributes: .concurrent)

            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)
            var faultSeen = false
            let lock = NSLock()

            // Thread 1: Repeated start attempts.
            group.enter()
            queue.async {
                for _ in 0..<30 {
                    let result = self.engine.start(configuration: config)
                    lock.lock()
                    if case .faulted = result { faultSeen = true }
                    lock.unlock()
                    Thread.sleep(forTimeInterval: 0.005)
                }
                group.leave()
            }

            // Thread 2: Repeated stop calls.
            group.enter()
            queue.async {
                for _ in 0..<30 {
                    self.engine.stop()
                    Thread.sleep(forTimeInterval: 0.005)
                }
                group.leave()
            }

            // Thread 3: Repeated retrieve calls.
            group.enter()
            queue.async {
                for _ in 0..<30 {
                    let result = self.engine.retrieveSamples(
                        from: 0, through: UInt64.max)
                    lock.lock()
                    if case .faulted = result { faultSeen = true }
                    lock.unlock()
                    Thread.sleep(forTimeInterval: 0.005)
                }
                group.leave()
            }

            group.wait()

            XCTAssertFalse(faultSeen,
                "No faulted state should occur during three-way contention")
            XCTAssertFalse(engine.isFaulted,
                "Engine should not be faulted after contention test")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: Frame Address Validation

        func test_realSampler_frameAddressesArePlausible() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            Thread.sleep(forTimeInterval: 0.2)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertGreaterThan(pr.samples.count, 0)

            for (i, sample) in pr.samples.enumerated() {
                let frames = pr.frames(for: sample)
                XCTAssertFalse(frames.isEmpty,
                    "Sample \(i) should have frames")
                for (j, addr) in frames.enumerated() {
                    // Frame addresses should be non-zero and in a plausible
                    // range for user-space code (above 4KB page-zero guard).
                    XCTAssertNotEqual(addr, 0,
                        "Sample \(i) frame \(j) should not be zero")
                    XCTAssertGreaterThan(addr, 0x1000,
                        "Sample \(i) frame \(j) should be above page-zero guard")
                }
            }
        }

        // MARK: Stop During Retrieve

        func test_stop_duringRetrieve_noCorruption() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            // Write many samples to make retrieval non-trivial.
            for ts: UInt64 in stride(from: 100, through: 10000, by: 100) {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: ts, frames: Array(repeating: UInt(ts), count: 10)))
            }

            let group = DispatchGroup()
            var retrieveResult: ProfilingEngine.RetrieveResult?

            // Retrieve on a background thread.
            group.enter()
            DispatchQueue.global().async {
                retrieveResult = self.engine.retrieveSamples(
                    from: 0, through: UInt64.max)
                group.leave()
            }

            // Immediately call stop() from the main thread.
            // stop() doesn't acquire the gate, so this exercises the
            // interaction between the non-gated stop and gated retrieve.
            engine.stop()

            group.wait()

            // Retrieve should still return valid data (not crash or corrupt).
            if let result = retrieveResult {
                switch result {
                case .success(let pr):
                    // If we got data, timestamps must be ordered.
                    if pr.samples.count > 1 {
                        for i in 1..<pr.samples.count {
                            XCTAssertGreaterThan(
                                pr.samples[i].timestamp,
                                pr.samples[i - 1].timestamp)
                        }
                    }
                case .busy, .notStarted:
                    break  // Acceptable under contention.
                default:
                    XCTFail("Unexpected retrieve result: \(result)")
                }
            }
        }

        // MARK: Zero-Frame Sample Via frames(for:)

        func test_framesAccessor_zeroFrameSample_returnsEmptySlice() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            // Write a sample by constructing a zero-frame record.
            // The C layer supports zero-frame records (header only).
            let emptyFrames: [UInt] = []
            XCTAssertTrue(engine.writeSampleForTesting(
                timestamp: 42, frames: emptyFrames))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }

            XCTAssertEqual(pr.samples.count, 1)
            let frames = pr.frames(for: pr.samples[0])
            XCTAssertTrue(frames.isEmpty,
                "frames(for:) on a zero-frame sample should return empty slice")
        }

        // MARK: Singleton Identity

        func test_shared_returnsSameInstance() {
            let a = ProfilingEngine.shared
            let b = ProfilingEngine.shared
            XCTAssertTrue(a === b,
                "ProfilingEngine.shared must always return the same instance")
        }

        // MARK: High-Throughput Stress

        func test_highThroughputRetrieve_duringActiveSampling() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 5)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            // Let some samples accumulate.
            Thread.sleep(forTimeInterval: 0.05)

            // Hammer retrieve from multiple threads.
            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.hightp", attributes: .concurrent)
            var corruptionCount = 0
            var successCount = 0
            let lock = NSLock()

            let totalCalls = 200
            for _ in 0..<totalCalls {
                group.enter()
                queue.async {
                    let result = self.engine.retrieveSamples(
                        from: 0, through: UInt64.max)
                    lock.lock()
                    if case .success(let pr) = result {
                        successCount += 1
                        if pr.samples.count > 1 {
                            for i in 1..<pr.samples.count {
                                if pr.samples[i].timestamp
                                    <= pr.samples[i - 1].timestamp
                                {
                                    corruptionCount += 1
                                    break
                                }
                            }
                        }
                        for sample in pr.samples {
                            if sample.frameRange.upperBound > pr.frames.count {
                                corruptionCount += 1
                                break
                            }
                        }
                    }
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            XCTAssertGreaterThan(successCount, 0,
                "At least some high-throughput retrieves should succeed")
            XCTAssertEqual(corruptionCount, 0,
                "No corruption during high-throughput retrieve stress test")
        }

        // MARK: Fault Injection with nil reason

        func test_injectFault_nilReason_reportsNoReasonGiven() {
            emb_sampler_inject_fault_for_testing(nil)
            XCTAssertTrue(engine.isFaulted)

            // The C layer should use "no reason given" fallback.
            let reason = engine.faultReason
            XCTAssertNotNil(reason, "faultReason should not be nil")
            XCTAssertEqual(reason, "no reason given")

            // start should return faulted with the fallback reason.
            let result = engine.start()
            if case .faulted(let r) = result {
                XCTAssertEqual(r, "no reason given")
            } else {
                XCTFail("Expected .faulted, got \(result)")
            }
        }

        // MARK: Non-Main-Thread Start

        func test_start_fromNonMainThread_withoutCachedMainThread_fails() {
            // Clear cached main thread info to simulate the case where the
            // constructor ran on a non-main thread (e.g. dlopen from background).
            emb_sampler_set_main_thread_for_testing(0, nil)

            let expectation = expectation(description: "start from background")
            var result: ProfilingEngine.StartResult?

            DispatchQueue.global().async {
                result = self.engine.start()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
            XCTAssertEqual(result, .samplerStartFailed,
                "Starting from non-main thread without cached info should fail")
        }

        // MARK: Buffer Reset Retry Under Contention

        func test_start_sameCapacity_whileReaderActive_handlesGracefully() {
            // Exercise the retry loop in start() that retries ring buffer
            // reset up to 3 times when a concurrent reader blocks the Dekker
            // protocol. The outcome should be either .started (reset succeeded)
            // or .samplerBusy (all retries failed). Never a crash or fault.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)

            // Allocate buffer and write data so there's something to read.
            XCTAssertTrue(engine.allocateBufferForTesting(configuration: config))
            for ts: UInt64 in stride(from: 100, through: 5000, by: 100) {
                XCTAssertTrue(engine.writeSampleForTesting(
                    timestamp: ts, frames: Array(repeating: UInt(ts), count: 20)))
            }

            // Spawn a reader that continuously retrieves while we try to start.
            final class StopFlag: @unchecked Sendable {
                private let lock = NSLock()
                private var _stop = false
                var isSet: Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return _stop
                }
                func set() {
                    lock.lock()
                    _stop = true
                    lock.unlock()
                }
            }
            let stop = StopFlag()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                while !stop.isSet {
                    _ = self.engine.retrieveSamples(from: 0, through: UInt64.max)
                }
                group.leave()
            }

            // Try to start (which resets the existing same-capacity buffer).
            // The reader may block the reset, exercising the retry path.
            var startedCount = 0
            var busyCount = 0
            for _ in 0..<10 {
                let result = engine.start(configuration: config)
                switch result {
                case .started:
                    startedCount += 1
                    engine.stop()
                    XCTAssertTrue(waitForFullStop())
                case .samplerBusy, .operationInProgress:
                    busyCount += 1
                default:
                    XCTFail("Unexpected result during reset contention: \(result)")
                }
            }

            stop.set()
            group.wait()

            XCTAssertEqual(startedCount + busyCount, 10,
                "All attempts should return .started or .samplerBusy")
            XCTAssertFalse(engine.isFaulted,
                "Engine should not fault during reset contention")
        }

        // MARK: Corrupted frame_count Defense-in-Depth

        func test_retrieveSamples_corruptedFrameCount_stopsParsingGracefully() {
            XCTAssertTrue(engine.allocateBufferForTesting())

            // Write two valid samples.
            XCTAssertTrue(engine.writeSampleForTesting(
                timestamp: 100, frames: [0xAAAA, 0xBBBB]))
            XCTAssertTrue(engine.writeSampleForTesting(
                timestamp: 200, frames: [0xCCCC, 0xDDDD]))

            // Verify both are readable before corruption.
            let before = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let prBefore) = before else {
                XCTFail("Expected .success, got \(before)")
                return
            }
            XCTAssertEqual(prBefore.samples.count, 2)

            // Corrupt the second record's frame_count by writing directly to
            // the ring buffer. The record header's frame_count field is at
            // offset 4 (after the 4-byte seq field).
            guard let ringBuffer = engine.ringBuffer else {
                XCTFail("ringBuffer should exist")
                return
            }

            // Find the second record's position. First record: header(16) + 2 frames(16) = 32 bytes.
            let firstRecordSize = 16 + 2 * 8  // 32 bytes
            let secondHeaderOffset = firstRecordSize
            let frameCountOffset = secondHeaderOffset + 4  // Skip seq field

            // Write an impossibly large frame_count (> EMB_MAX_STACK_FRAMES).
            let data = ringBuffer.pointee.data!
            data.advanced(by: frameCountOffset).withMemoryRebound(
                to: UInt32.self, capacity: 1
            ) { ptr in
                ptr.pointee = 0xFFFF_FFFF  // Way above 1024
            }

            // retrieveSamples should stop parsing at the corrupted record.
            let after = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let prAfter) = after else {
                XCTFail("Expected .success even with corruption, got \(after)")
                return
            }

            // Should get at most 1 sample (the first valid one). The corrupted
            // second record should be skipped, not cause a crash.
            XCTAssertLessThanOrEqual(prAfter.samples.count, 1,
                "Should stop parsing at corrupted frame_count")
        }

        // MARK: Minimum Valid Configuration Boundaries

        func test_start_minimumInterval_succeeds() {
            // samplingIntervalMs=10, minSamplingIntervalMs=4 is the most
            // aggressive valid configuration. Verify it starts and captures.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 10, minSamplingIntervalMs: 4)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            // Let it run very briefly at 1000 Hz.
            Thread.sleep(forTimeInterval: 0.05)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }
            XCTAssertGreaterThan(pr.samples.count, 0,
                "Should capture samples even at minimum 1ms interval")
        }

        func test_start_minimumMaxFrames_succeeds() {
            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 10,
                maxFramesPerSample: 1)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            Thread.sleep(forTimeInterval: 0.15)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }
            XCTAssertGreaterThan(pr.samples.count, 0,
                "Should capture samples with maxFrames=1")
            for (i, sample) in pr.samples.enumerated() {
                let frames = pr.frames(for: sample)
                XCTAssertLessThanOrEqual(frames.count, 1,
                    "Sample \(i) should have at most 1 frame")
            }
        }

        func test_start_minimumBufferCapacity_succeeds() {
            // bufferCapacityBytes just above 128 KB minimum; gets rounded up to a page boundary.
            let config = ProfilingConfiguration(
                samplingIntervalMs: 100, minSamplingIntervalMs: 10,
                bufferCapacityBytes: 131073)
            XCTAssertEqual(engine.start(configuration: config), .started)
            XCTAssertTrue(waitForCapturing(true))

            Thread.sleep(forTimeInterval: 0.15)

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))

            let result = engine.retrieveSamples(from: 0, through: UInt64.max)
            guard case .success(let pr) = result else {
                XCTFail("Expected .success, got \(result)")
                return
            }
            // With a single-page buffer, some samples may be evicted, but
            // we should still get at least one.
            XCTAssertGreaterThan(pr.samples.count, 0,
                "Should capture samples even with minimum buffer capacity")
        }

        // MARK: High-Pressure Concurrent Lifecycle

        func test_highPressure_concurrentStartStopRetrieve() {
            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "test.engine.highpressure", attributes: .concurrent)

            let config = ProfilingConfiguration(
                samplingIntervalMs: 50, minSamplingIntervalMs: 10)
            var faultSeen = false
            var corruptionSeen = false
            let lock = NSLock()

            let iterations = 100

            // Thread 1: Rapid start attempts.
            group.enter()
            queue.async {
                for _ in 0..<iterations {
                    let result = self.engine.start(configuration: config)
                    lock.lock()
                    if case .faulted = result { faultSeen = true }
                    lock.unlock()
                    Thread.sleep(forTimeInterval: 0.001)
                }
                group.leave()
            }

            // Thread 2: Rapid stop calls.
            group.enter()
            queue.async {
                for _ in 0..<iterations {
                    self.engine.stop()
                    Thread.sleep(forTimeInterval: 0.001)
                }
                group.leave()
            }

            // Threads 3-6: Rapid retrieve calls.
            for _ in 0..<4 {
                group.enter()
                queue.async {
                    for _ in 0..<iterations {
                        let result = self.engine.retrieveSamples(
                            from: 0, through: UInt64.max)
                        lock.lock()
                        if case .faulted = result { faultSeen = true }
                        if case .success(let pr) = result, pr.samples.count > 1 {
                            for i in 1..<pr.samples.count {
                                if pr.samples[i].timestamp
                                    <= pr.samples[i - 1].timestamp
                                {
                                    corruptionSeen = true
                                    break
                                }
                            }
                            for sample in pr.samples {
                                if sample.frameRange.upperBound > pr.frames.count {
                                    corruptionSeen = true
                                    break
                                }
                            }
                        }
                        lock.unlock()
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                    group.leave()
                }
            }

            group.wait()

            XCTAssertFalse(faultSeen,
                "No faulted state should occur during high-pressure contention")
            XCTAssertFalse(corruptionSeen,
                "No data corruption should occur during high-pressure contention")
            XCTAssertFalse(engine.isFaulted,
                "Engine should not be faulted after high-pressure test")

            engine.stop()
            XCTAssertTrue(waitForCapturing(false))
        }

        // MARK: - Private helpers

        /// Inject a fault at the C level. Wraps the C test-only API.
        private func _injectFault(_ reason: String) {
            // The C function copies the reason into a static buffer via strlcpy,
            // so it's safe to pass Swift's temporary C string bridging directly.
            emb_sampler_inject_fault_for_testing(reason)
        }
    }

#endif
