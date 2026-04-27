//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

import Darwin
import EmbraceProfilingSampler
import EmbraceProfilingTestSupport
import EmbraceProfilingTestSupportNoFP
import XCTest

#if canImport(KSCrash)
    import KSCrash
#else
    import KSCrashRecording
#endif

/// Benchmarks comparing FP-based stack walking vs KSCrash fallback on stacks
/// compiled with and without frame pointers.
///
/// `-fomit-frame-pointer` takes effect on both arm64 and x86_64 with modern
/// Clang. When frame pointers are omitted, both the FP walker and KSCrash's
/// `captureBacktrace` lose most frames (both use FP chain walking internally).
///
/// ## TODO: Update when KSCrash gains DWARF unwinding
///
/// KSCrash's DWARF-based unwinder (currently in beta) will be able to recover
/// full stacks from frameless code. When that lands:
///
/// 1. `test_benchmark_kscrash_noFPStack`: add an assertion that KSCrash
///    recovers at least `stackDepth` frames on frameless code, since DWARF
///    unwinding does not depend on the FP chain.
///
/// 2. `test_benchmark_fpWalk_noFPStack`: the FP walker will still only get
///    a few frames (it can never unwind frameless code). No change needed.
final class FallbackBenchmarks: XCTestCase {

    private static let walksPerIteration = 10_000
    private static let stackDepth: size_t = 30
    private static let maxFrames = 512

    // MARK: - Helpers

    private func resolveStackBounds(port: thread_t) -> (bottom: UnsafeRawPointer, top: UnsafeRawPointer)? {
        guard let pth = pthread_from_mach_thread_np(port) else { return nil }
        let top = pthread_get_stackaddr_np(pth)
        let size = pthread_get_stacksize_np(pth)
        return (UnsafeRawPointer(top - size), UnsafeRawPointer(top))
    }

    private func walkWithFP(port: thread_t, stackBottom: UnsafeRawPointer, stackTop: UnsafeRawPointer) -> Int {
        var frames = [UInt](repeating: 0, count: Self.maxFrames)
        var count = 0
        emb_stack_walk(port, stackBottom, stackTop, &frames, Self.maxFrames, &count)
        return count
    }

    private func walkWithKSCrash(port: thread_t) -> Int {
        guard let pthread = pthread_from_mach_thread_np(port) else { return 0 }
        var frames = [UInt](repeating: 0, count: Self.maxFrames)
        let count = captureBacktrace(thread: pthread, addresses: &frames, count: Int32(Self.maxFrames))
        return Int(count)
    }

    // MARK: - Normal stack (with frame pointers)

    func test_benchmark_fpWalk_normalStack() throws {
        guard let thread = emb_test_thread_create(Self.stackDepth) else {
            XCTFail("Failed to create test thread")
            return
        }
        defer { emb_test_thread_destroy(thread) }
        let port = emb_test_thread_get_port(thread)

        guard let bounds = resolveStackBounds(port: port) else {
            XCTFail("Failed to resolve stack bounds")
            return
        }

        let kr = thread_suspend(port)
        XCTAssertEqual(kr, KERN_SUCCESS)
        defer { thread_resume(port) }

        let frameCount = walkWithFP(port: port, stackBottom: bounds.bottom, stackTop: bounds.top)
        print("FP walk (normal stack): \(frameCount) frames")
        XCTAssertGreaterThanOrEqual(frameCount, Int(Self.stackDepth),
            "FP walker should capture at least \(Self.stackDepth) frames on a normal stack")

        measure {
            for _ in 0..<Self.walksPerIteration {
                _ = self.walkWithFP(port: port, stackBottom: bounds.bottom, stackTop: bounds.top)
            }
        }
    }

    func test_benchmark_kscrash_normalStack() throws {
        guard let thread = emb_test_thread_create(Self.stackDepth) else {
            XCTFail("Failed to create test thread")
            return
        }
        defer { emb_test_thread_destroy(thread) }
        let port = emb_test_thread_get_port(thread)

        let kr = thread_suspend(port)
        XCTAssertEqual(kr, KERN_SUCCESS)
        defer { thread_resume(port) }

        let frameCount = walkWithKSCrash(port: port)
        print("KSCrash walk (normal stack): \(frameCount) frames")
        XCTAssertGreaterThan(frameCount, 0,
            "KSCrash walker should capture at least 1 frame on a normal stack")

        measure {
            for _ in 0..<Self.walksPerIteration {
                _ = self.walkWithKSCrash(port: port)
            }
        }
    }

    // MARK: - No-FP stack (compiled with -fomit-frame-pointer)

    func test_benchmark_fpWalk_noFPStack() throws {
        guard let thread = emb_test_thread_nofp_create(Self.stackDepth) else {
            XCTFail("Failed to create no-FP test thread")
            return
        }
        defer { emb_test_thread_nofp_destroy(thread) }
        let port = emb_test_thread_nofp_get_port(thread)

        guard let bounds = resolveStackBounds(port: port) else {
            XCTFail("Failed to resolve stack bounds")
            return
        }

        let kr = thread_suspend(port)
        XCTAssertEqual(kr, KERN_SUCCESS)
        defer { thread_resume(port) }

        let frameCount = walkWithFP(port: port, stackBottom: bounds.bottom, stackTop: bounds.top)
        print("FP walk (no-FP stack): \(frameCount) frames")
        // Modern Clang honors -fomit-frame-pointer on all architectures
        // (including arm64). Without frame pointers, the FP walker can only
        // recover a few frames at the top of the stack. It should not crash
        // and should return at least 1 frame.
        XCTAssertGreaterThan(frameCount, 0,
            "FP walker should capture at least the top frame even without FP chain")

        measure {
            for _ in 0..<Self.walksPerIteration {
                _ = self.walkWithFP(port: port, stackBottom: bounds.bottom, stackTop: bounds.top)
            }
        }
    }

    /// TODO: When KSCrash gains DWARF unwinding, add an assertion here:
    ///   XCTAssertGreaterThanOrEqual(frameCount, Int(Self.stackDepth),
    ///       "KSCrash with DWARF unwinding should recover full stack from frameless code")
    func test_benchmark_kscrash_noFPStack() throws {
        guard let thread = emb_test_thread_nofp_create(Self.stackDepth) else {
            XCTFail("Failed to create no-FP test thread")
            return
        }
        defer { emb_test_thread_nofp_destroy(thread) }
        let port = emb_test_thread_nofp_get_port(thread)

        let kr = thread_suspend(port)
        XCTAssertEqual(kr, KERN_SUCCESS)
        defer { thread_resume(port) }

        let frameCount = walkWithKSCrash(port: port)
        print("KSCrash walk (no-FP stack): \(frameCount) frames")

        measure {
            for _ in 0..<Self.walksPerIteration {
                _ = self.walkWithKSCrash(port: port)
            }
        }
    }

}

#endif
