//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    /// File-private state for mock fallback walkers.
    /// Written by the sampler worker thread, read by the test thread after stop.
    /// No concurrent access: the test thread reads only after the worker exits
    /// (ensured by waitForSamplerToStop, which joins the worker via is_active polling).
    private var gFallbackCallCount: Int = 0
    private let gFallbackSentinel: UInt = 0xFADE_FADE

    /// Tests verifying the fallback stack walker path in the C sampler.
    ///
    /// The sampler calls the fallback walker when the primary FP-based walker
    /// returns fewer frames than `min_frames`. These tests exercise that path
    /// using mock callbacks with various return values.
    final class SamplerFallbackTests: XCTestCase {

        override func setUp() {
            super.setUp()
            gFallbackCallCount = 0
            emb_sampler_reset_for_testing()
        }

        override func tearDown() {
            emb_sampler_stop()
            _ = waitForSamplerToStop()
            emb_sampler_reset_for_testing()
            super.tearDown()
        }

        // MARK: - Fallback invocation

        func test_fallbackWalker_invokedWhenBelowMinFrames() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // min_frames=999 ensures the FP walker (which typically captures
            // ~15-30 frames on a sleeping main thread) always falls below the
            // threshold, triggering the fallback on every sample.
            let config = emb_sampler_config_t(
                sampling_interval_ms: 50,
                min_sampling_interval_ms: 10,
                max_frames: 128,
                min_frames: 999,
                fallback_walker: { _, framesOut, maxFrames, _ in
                    gFallbackCallCount += 1
                    guard let framesOut = framesOut, maxFrames > 0 else { return 0 }
                    framesOut[0] = gFallbackSentinel
                    return 1
                }
            )

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            Thread.sleep(forTimeInterval: 0.3)
            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())

            XCTAssertGreaterThan(gFallbackCallCount, 0,
                "Fallback walker should have been called at least once")

            // Verify the sentinel frame is in the ring buffer.
            let records = testReadRange(buf, 0, UInt64.max)
            XCTAssertGreaterThan(records.count, 0,
                "Should have captured at least one sample via fallback")

            for (i, record) in records.enumerated() {
                XCTAssertEqual(record.frame_count, 1,
                    "Sample \(i): fallback returns 1 frame")
                XCTAssertEqual(record.frames[0], gFallbackSentinel,
                    "Sample \(i): frame should be the fallback sentinel value")
            }
        }

        func test_fallbackWalker_returningZero_writesNothing() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let config = emb_sampler_config_t(
                sampling_interval_ms: 50,
                min_sampling_interval_ms: 10,
                max_frames: 128,
                min_frames: 999,
                fallback_walker: { _, _, _, _ in
                    gFallbackCallCount += 1
                    return 0  // Zero frames → sampler skips the write.
                }
            )

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            Thread.sleep(forTimeInterval: 0.2)
            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())

            XCTAssertGreaterThan(gFallbackCallCount, 0,
                "Fallback should have been invoked")

            let records = testReadRange(buf, 0, UInt64.max)
            XCTAssertEqual(records.count, 0,
                "No records should be written when fallback returns 0 frames")
        }

        func test_fallbackWalker_returningNegative_writesNothing() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // The C code clamps negative returns to 0: frame_count = result < 0 ? 0 : result
            let config = emb_sampler_config_t(
                sampling_interval_ms: 50,
                min_sampling_interval_ms: 10,
                max_frames: 128,
                min_frames: 999,
                fallback_walker: { _, _, _, _ in
                    gFallbackCallCount += 1
                    return -1
                }
            )

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            Thread.sleep(forTimeInterval: 0.2)
            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())

            XCTAssertGreaterThan(gFallbackCallCount, 0,
                "Fallback should have been invoked")

            let records = testReadRange(buf, 0, UInt64.max)
            XCTAssertEqual(records.count, 0,
                "No records should be written when fallback returns negative")
        }

        func test_fallbackWalker_notInvokedWhenAboveMinFrames() {
            let buf = emb_ring_buffer_create(1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            // min_frames=1: the FP walker almost always returns >= 1 frame
            // on a sleeping main thread, so the fallback should never fire.
            let config = emb_sampler_config_t(
                sampling_interval_ms: 50,
                min_sampling_interval_ms: 10,
                max_frames: 128,
                min_frames: 1,
                fallback_walker: { _, _, _, _ in
                    gFallbackCallCount += 1
                    return 0
                }
            )

            XCTAssertEqual(emb_sampler_start(buf, config), EMB_SAMPLER_START_OK)
            Thread.sleep(forTimeInterval: 0.2)
            emb_sampler_stop()
            XCTAssertTrue(waitForSamplerToStop())

            XCTAssertEqual(gFallbackCallCount, 0,
                "Fallback should not be called when FP walker meets min_frames")

            let records = testReadRange(buf, 0, UInt64.max)
            XCTAssertGreaterThan(records.count, 0,
                "Should have captured samples from the primary FP walker")
        }
    }

#endif
