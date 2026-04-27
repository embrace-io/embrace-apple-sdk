//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    final class StackWalkerTests: XCTestCase {

        // MARK: - Helpers

        /// Resolve stack bounds for a pthread (safe to call before suspend).
        private func stackBounds(for pth: pthread_t) -> (bottom: UnsafeRawPointer, top: UnsafeRawPointer) {
            let top = pthread_get_stackaddr_np(pth)
            let size = pthread_get_stacksize_np(pth)
            return (UnsafeRawPointer(top - size), UnsafeRawPointer(top))
        }

        /// Walk the stack of a test thread (suspends, walks, resumes).
        private func walkTestThread(
            _ testThread: emb_test_thread_t,
            maxFrames: Int = 512
        ) -> (success: Bool, count: Int, frames: [UInt]) {
            let port = emb_test_thread_get_port(testThread)
            guard let pth = pthread_from_mach_thread_np(port) else {
                return (false, 0, [])
            }
            let bounds = stackBounds(for: pth)

            let suspendResult = thread_suspend(port)
            guard suspendResult == KERN_SUCCESS else {
                return (false, 0, [])
            }

            var frames = [UInt](repeating: 0, count: maxFrames)
            var count = 0
            let walkResult = emb_stack_walk(port, bounds.bottom, bounds.top,
                                            &frames, maxFrames, &count)

            thread_resume(port)
            return (walkResult, count, Array(frames.prefix(count)))
        }

        // MARK: - Existing tests

        func test_stackWalk_capturesFramesFromSuspendedThread() throws {
            var targetPthread: pthread_t?

            // Spawn a thread that sleeps, giving it a non-trivial stack to walk.
            let ret = pthread_create(
                &targetPthread, nil,
                { _ -> UnsafeMutableRawPointer? in
                    Thread.sleep(forTimeInterval: 5.0)
                    return nil
                }, nil)
            XCTAssertEqual(ret, 0, "pthread_create should succeed")
            guard let targetPthread = targetPthread else {
                XCTFail("Failed to create thread")
                return
            }
            defer { pthread_join(targetPthread, nil) }

            // Give the thread time to enter sleep.
            Thread.sleep(forTimeInterval: 0.05)

            let machThread = pthread_mach_thread_np(targetPthread)
            let bounds = stackBounds(for: targetPthread)

            // Suspend the target thread so we can safely walk its stack.
            let suspendResult = thread_suspend(machThread)
            XCTAssertEqual(suspendResult, KERN_SUCCESS, "thread_suspend should succeed")

            // Walk the stack.
            let maxFrames = 512
            var frames = [UInt](repeating: 0, count: maxFrames)
            var count = 0
            let walkResult = emb_stack_walk(machThread, bounds.bottom, bounds.top,
                                            &frames, maxFrames, &count)

            // Resume immediately after walking.
            let resumeResult = thread_resume(machThread)
            XCTAssertEqual(resumeResult, KERN_SUCCESS, "thread_resume should succeed")

            // Verify the walk succeeded and produced frames.
            XCTAssertTrue(walkResult, "emb_stack_walk should succeed")
            XCTAssertGreaterThan(count, 0, "Should capture at least one frame")

            // Every reported frame address should be non-zero.
            for i in 0..<count {
                XCTAssertNotEqual(frames[i], 0, "Frame \(i) should be a non-zero address")
            }
        }

        func test_stackWalk_failsWithInvalidThread() {
            let maxFrames = 64
            var frames = [UInt](repeating: 0, count: maxFrames)
            var count = 0

            // Mach thread port 0 is invalid; the walk should fail gracefully.
            // Provide dummy stack bounds. The call should fail on thread_get_state.
            let dummy = UnsafeRawPointer(bitPattern: 1)!
            let dummyTop = UnsafeRawPointer(bitPattern: UInt.max)!
            let result = emb_stack_walk(0, dummy, dummyTop, &frames, maxFrames, &count)
            XCTAssertFalse(result, "Should fail with invalid thread")
            XCTAssertEqual(count, 0)
        }

        func test_stackWalk_failsWithNullOutputs() {
            var count = 0
            let dummy = UnsafeRawPointer(bitPattern: 1)!
            let dummyTop = UnsafeRawPointer(bitPattern: UInt.max)!
            let result = emb_stack_walk(mach_thread_self(), dummy, dummyTop, nil, 64, &count)
            XCTAssertFalse(result, "Should fail with null frames_out")
        }

        func test_stackWalk_failsWithZeroMaxFrames() {
            var frames = [UInt](repeating: 0, count: 1)
            var count = 0
            let dummy = UnsafeRawPointer(bitPattern: 1)!
            let dummyTop = UnsafeRawPointer(bitPattern: UInt.max)!
            let result = emb_stack_walk(mach_thread_self(), dummy, dummyTop, &frames, 0, &count)
            XCTAssertFalse(result, "Should fail with max_frames == 0")
        }

        // MARK: - Depth validation tests (using emb_test_thread)

        func test_stackWalk_shallowStack_capturesAtLeastDepth() {
            guard let t = emb_test_thread_create(10) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let result = walkTestThread(t)
            XCTAssertTrue(result.success, "Walk should succeed")
            XCTAssertGreaterThanOrEqual(result.count, 10,
                "Should capture at least 10 frames for depth-10 stack, got \(result.count)")
        }

        func test_stackWalk_deepStack_capturesAtLeastDepth() {
            guard let t = emb_test_thread_create(100) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let result = walkTestThread(t)
            XCTAssertTrue(result.success, "Walk should succeed")
            XCTAssertGreaterThanOrEqual(result.count, 100,
                "Should capture at least 100 frames for depth-100 stack, got \(result.count)")
        }

        func test_stackWalk_depthIncreases_withStackDepth() {
            guard let shallow = emb_test_thread_create(10) else {
                XCTFail("Failed to create shallow test thread")
                return
            }
            defer { emb_test_thread_destroy(shallow) }

            guard let deep = emb_test_thread_create(50) else {
                XCTFail("Failed to create deep test thread")
                return
            }
            defer { emb_test_thread_destroy(deep) }

            let shallowResult = walkTestThread(shallow)
            let deepResult = walkTestThread(deep)

            XCTAssertTrue(shallowResult.success && deepResult.success)
            XCTAssertGreaterThan(deepResult.count, shallowResult.count,
                "Deeper stack (\(deepResult.count)) should yield more frames than shallow (\(shallowResult.count))")
        }

        func test_stackWalk_multipleWalks_consistent() {
            guard let t = emb_test_thread_create(20) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let port = emb_test_thread_get_port(t)
            guard let pth = pthread_from_mach_thread_np(port) else {
                XCTFail("Failed to get pthread from mach thread")
                return
            }
            let bounds = stackBounds(for: pth)

            // Suspend once, walk multiple times.
            let suspendResult = thread_suspend(port)
            XCTAssertEqual(suspendResult, KERN_SUCCESS)

            var firstFrames: [UInt]?
            var firstCount = 0

            for i in 0..<5 {
                let maxFrames = 512
                var frames = [UInt](repeating: 0, count: maxFrames)
                var count = 0
                let ok = emb_stack_walk(port, bounds.bottom, bounds.top,
                                        &frames, maxFrames, &count)
                XCTAssertTrue(ok, "Walk \(i) should succeed")

                if let first = firstFrames {
                    XCTAssertEqual(count, firstCount,
                        "Walk \(i) count (\(count)) should match first walk (\(firstCount))")
                    for j in 0..<min(count, firstCount) {
                        XCTAssertEqual(frames[j], first[j],
                            "Frame \(j) on walk \(i) should match first walk")
                    }
                } else {
                    firstFrames = Array(frames.prefix(count))
                    firstCount = count
                }
            }

            thread_resume(port)
        }

        func test_stackWalk_respectsMaxFramesLimit() {
            guard let t = emb_test_thread_create(100) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let result = walkTestThread(t, maxFrames: 5)
            XCTAssertTrue(result.success, "Walk should succeed")
            XCTAssertEqual(result.count, 5,
                "Should capture exactly max_frames (5) frames, got \(result.count)")
        }

        // MARK: - Boundary / null parameter tests

        func test_stackWalk_nullStackBounds_returnsFalse() {
            guard let t = emb_test_thread_create(10) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let port = emb_test_thread_get_port(t)
            let suspendResult = thread_suspend(port)
            XCTAssertEqual(suspendResult, KERN_SUCCESS)

            var frames = [UInt](repeating: 0, count: 64)
            var count = 0
            // Null stack_bottom.
            let result = emb_stack_walk(port, nil, UnsafeRawPointer(bitPattern: UInt.max)!,
                                        &frames, 64, &count)
            XCTAssertFalse(result, "Should fail with null stack_bottom")

            thread_resume(port)
        }

        func test_stackWalk_invertedStackBounds_returnsFalse() {
            guard let t = emb_test_thread_create(10) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let port = emb_test_thread_get_port(t)
            guard let pth = pthread_from_mach_thread_np(port) else {
                XCTFail("Failed to get pthread")
                return
            }
            let bounds = stackBounds(for: pth)

            let suspendResult = thread_suspend(port)
            XCTAssertEqual(suspendResult, KERN_SUCCESS)

            var frames = [UInt](repeating: 0, count: 64)
            var count = 0
            // Inverted: bottom > top.
            let result = emb_stack_walk(port, bounds.top, bounds.bottom,
                                        &frames, 64, &count)
            XCTAssertFalse(result, "Should fail with inverted stack bounds")

            thread_resume(port)
        }

        func test_stackWalk_nullCountOut_returnsFalse() {
            guard let t = emb_test_thread_create(10) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(t) }

            let port = emb_test_thread_get_port(t)
            guard let pth = pthread_from_mach_thread_np(port) else {
                XCTFail("Failed to get pthread")
                return
            }
            let bounds = stackBounds(for: pth)

            let suspendResult = thread_suspend(port)
            XCTAssertEqual(suspendResult, KERN_SUCCESS)

            var frames = [UInt](repeating: 0, count: 64)
            let result = emb_stack_walk(port, bounds.bottom, bounds.top,
                                        &frames, 64, nil)
            XCTAssertFalse(result, "Should fail with null count_out")

            thread_resume(port)
        }
    }

#endif
