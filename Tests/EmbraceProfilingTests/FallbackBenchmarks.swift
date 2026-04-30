//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

import Darwin
@testable import EmbraceProfiling
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
/// `-fomit-frame-pointer` takes effect on x86_64, and Apple suppresses it on
/// arm64, but there are other ways for the FP to be unavailable:
/// - mid-prologue or mid-epilogue
/// - in a leaf function before the frame is set up
/// - hand written assembly
/// - signal trampolines
/// - objc_msgSend shenanigans
/// - game engines, embedded VMs, Unity, Unreal, etc
/// When frame pointers are omitted the FP walker loses most frames. The
/// KSCrash fallback currently also relies on FP chains, so it is not
/// meaningfully better for fully frameless stacks right now. it is structured
/// as a fallback in anticipation of KSCrash gaining DWARF-based unwinding (see
/// TODO below), which will recover full stacks regardless of FP presence.
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

    private func walkWithFallback(port: thread_t) -> Int {
        let result = captureStack(thread: port, maxFrames: Self.maxFrames)
        return result.frames.count
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
        print("FP walk (no-FP stack): \(frameCount) frames — on arm64 this should match the normal stack")

        measure {
            for _ in 0..<Self.walksPerIteration {
                _ = self.walkWithFP(port: port, stackBottom: bounds.bottom, stackTop: bounds.top)
            }
        }
    }

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

    func test_benchmark_fallback_noFPStack() throws {
        guard let thread = emb_test_thread_nofp_create(Self.stackDepth) else {
            XCTFail("Failed to create no-FP test thread")
            return
        }
        defer { emb_test_thread_nofp_destroy(thread) }
        let port = emb_test_thread_nofp_get_port(thread)

        let kr = thread_suspend(port)
        XCTAssertEqual(kr, KERN_SUCCESS)
        defer { thread_resume(port) }

        let frameCount = walkWithFallback(port: port)
        print("Fallback (no-FP stack): \(frameCount) frames — tries FP first, falls back to KSCrash")

        measure {
            for _ in 0..<Self.walksPerIteration {
                _ = self.walkWithFallback(port: port)
            }
        }
    }
}

#endif
