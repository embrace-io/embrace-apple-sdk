//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
    import XCTest

    final class StackWalkerBenchmarks: XCTestCase {

        // MARK: - Helpers

        /// Number of walks per measured iteration, so the total time is large
        /// enough for XCTest to report meaningful values.
        private static let walksPerIteration = 10_000

        private func walkSuspendedThread(port: thread_t,
                                         stackBottom: UnsafeRawPointer,
                                         stackTop: UnsafeRawPointer) -> Int {
            let maxFrames = 1024
            var frames = [UInt](repeating: 0, count: maxFrames)
            var count = 0
            emb_stack_walk(port, stackBottom, stackTop, &frames, maxFrames, &count)
            return count
        }

        private func benchmarkWalk(stackDepth: size_t, label: String) throws {
            guard let thread = emb_test_thread_create(stackDepth) else {
                XCTFail("Failed to create test thread")
                return
            }
            defer { emb_test_thread_destroy(thread) }
            let port = emb_test_thread_get_port(thread)

            // Resolve stack bounds before suspending.
            let pth = pthread_from_mach_thread_np(port)!
            let top = pthread_get_stackaddr_np(pth)
            let size = pthread_get_stacksize_np(pth)
            let stackBottom = UnsafeRawPointer(top - size)
            let stackTop = UnsafeRawPointer(top)

            let kr = thread_suspend(port)
            XCTAssertEqual(kr, KERN_SUCCESS)
            defer { thread_resume(port) }

            let frameCount = walkSuspendedThread(port: port, stackBottom: stackBottom, stackTop: stackTop)
            print("\(label): \(frameCount) frames, \(Self.walksPerIteration) walks per iteration")

            measure {
                for _ in 0..<Self.walksPerIteration {
                    _ = self.walkSuspendedThread(port: port, stackBottom: stackBottom, stackTop: stackTop)
                }
            }
        }

        // MARK: - Benchmarks

        func test_benchmark_shallowStack() throws {
            try benchmarkWalk(stackDepth: 10, label: "Shallow stack")
        }

        func test_benchmark_averageStack() throws {
            try benchmarkWalk(stackDepth: 30, label: "Average stack")
        }

        func test_benchmark_deepStack() throws {
            try benchmarkWalk(stackDepth: 100, label: "Deep stack")
        }

        func test_benchmark_veryDeepStack() throws {
            try benchmarkWalk(stackDepth: 500, label: "Very deep stack")
        }
    }

#endif
