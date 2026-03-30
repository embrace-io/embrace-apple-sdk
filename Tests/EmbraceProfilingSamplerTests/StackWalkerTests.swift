//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import XCTest

    final class StackWalkerTests: XCTestCase {

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

            // Suspend the target thread so we can safely walk its stack.
            let suspendResult = thread_suspend(machThread)
            XCTAssertEqual(suspendResult, KERN_SUCCESS, "thread_suspend should succeed")

            // Walk the stack.
            let maxFrames = 512
            var frames = [UInt](repeating: 0, count: maxFrames)
            var count = 0
            let walkResult = emb_stack_walk(machThread, &frames, maxFrames, &count)

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
            let result = emb_stack_walk(0, &frames, maxFrames, &count)
            XCTAssertFalse(result, "Should fail with invalid thread")
            XCTAssertEqual(count, 0)
        }

        func test_stackWalk_failsWithNullOutputs() {
            var count = 0
            let result = emb_stack_walk(mach_thread_self(), nil, 64, &count)
            XCTAssertFalse(result, "Should fail with null frames_out")
        }

        func test_stackWalk_failsWithZeroMaxFrames() {
            var frames = [UInt](repeating: 0, count: 1)
            var count = 0
            let result = emb_stack_walk(mach_thread_self(), &frames, 0, &count)
            XCTAssertFalse(result, "Should fail with max_frames == 0")
        }
    }

#endif
