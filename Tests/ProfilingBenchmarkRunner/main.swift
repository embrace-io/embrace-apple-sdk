//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

// Standalone benchmark runner for profiling stack walkers.
// Build: swift build --product ProfilingBenchmarkRunner --disable-sandbox
// Run:   .build/arm64-apple-macosx/debug/ProfilingBenchmarkRunner

#if !os(watchOS)

import Darwin
import EmbraceProfilingSampler
import EmbraceProfilingTestSupport
import EmbraceProfilingTestSupportNoFP

#if canImport(KSCrash)
    import KSCrash
#else
    import KSCrashRecording
#endif

// MARK: - Configuration

let iterations = 10_000
let maxFrames = 512
let stackDepth: size_t = 30

// MARK: - Helpers

func timeBlock(body: () -> Void) -> Double {
    // Warm up
    body()

    var best = Double.infinity
    for _ in 0..<5 {
        let start = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        body()
        let end = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let elapsed = Double(end - start) / 1e9
        best = min(best, elapsed)
    }
    return best
}

func walkFP(port: thread_t) -> Int {
    var frames = [UInt](repeating: 0, count: maxFrames)
    var count = 0
    emb_stack_walk(port, &frames, maxFrames, &count)
    return count
}

func walkKSCrash(port: thread_t) -> Int {
    guard let pthread = pthread_from_mach_thread_np(port) else { return 0 }
    var frames = [UInt](repeating: 0, count: maxFrames)
    let count = captureBacktrace(thread: pthread, addresses: &frames, count: Int32(maxFrames))
    return Int(count)
}

struct BenchResult {
    let label: String
    let frames: Int
    let totalSeconds: Double
    let perWalkNs: Double
}

func benchmark(label: String, port: thread_t, walker: (thread_t) -> Int) -> BenchResult {
    let frameCount = walker(port)
    let elapsed = timeBlock {
        for _ in 0..<iterations {
            _ = walker(port)
        }
    }
    let perWalk = (elapsed / Double(iterations)) * 1e9
    return BenchResult(label: label, frames: frameCount, totalSeconds: elapsed, perWalkNs: perWalk)
}

func printResult(_ r: BenchResult) {
    let perWalkUs = r.perWalkNs / 1000.0
    let paddedLabel = r.label.padding(toLength: 40, withPad: " ", startingAt: 0)
    print("  \(paddedLabel)  \(String(format: "%3d", r.frames)) frames  \(String(format: "%8.1f", r.perWalkNs)) ns/walk  (\(String(format: "%6.2f", perWalkUs)) µs/walk)")
}

func withSuspendedThread(port: thread_t, body: () -> Void) {
    let kr = thread_suspend(port)
    precondition(kr == KERN_SUCCESS, "thread_suspend failed: \(kr)")
    body()
    thread_resume(port)
}

// MARK: - Run benchmarks

print("Stack Walker Fallback Benchmarks")
print("================================")
print("Iterations per measurement: \(iterations)")
print("Stack depth: \(stackDepth)")
#if arch(arm64)
print("CPU: arm64")
#elseif arch(x86_64)
print("CPU: x86_64")
#endif
print()

// --- Normal stack (with frame pointers) ---
print("Normal stack (compiled with frame pointers):")

guard let normalThread = emb_test_thread_create(stackDepth) else {
    fatalError("Failed to create normal test thread")
}
let normalPort = emb_test_thread_get_port(normalThread)

var fpNormal: BenchResult!
var ksNormal: BenchResult!
withSuspendedThread(port: normalPort) {
    fpNormal = benchmark(label: "FP walk", port: normalPort, walker: walkFP)
    ksNormal = benchmark(label: "KSCrash captureBacktrace", port: normalPort, walker: walkKSCrash)
}
printResult(fpNormal)
printResult(ksNormal)
emb_test_thread_destroy(normalThread)

// --- No-FP stack (compiled with -fomit-frame-pointer) ---
print()
print("No-FP stack (compiled with -fomit-frame-pointer):")

guard let nofpThread = emb_test_thread_nofp_create(stackDepth) else {
    fatalError("Failed to create no-FP test thread")
}
let nofpPort = emb_test_thread_nofp_get_port(nofpThread)

var fpNofp: BenchResult!
var ksNofp: BenchResult!
withSuspendedThread(port: nofpPort) {
    fpNofp = benchmark(label: "FP walk", port: nofpPort, walker: walkFP)
    ksNofp = benchmark(label: "KSCrash captureBacktrace", port: nofpPort, walker: walkKSCrash)
}
printResult(fpNofp)
printResult(ksNofp)
emb_test_thread_nofp_destroy(nofpThread)

// --- Summary ---
print()
print("Summary:")
print("--------")

let fpSpeedup = ksNormal.perWalkNs / fpNormal.perWalkNs
print("  FP walk is \(String(format: "%.1f", fpSpeedup))x faster than KSCrash on normal stacks")

if fpNofp.frames < fpNormal.frames {
    let loss = (1.0 - Double(fpNofp.frames) / Double(fpNormal.frames)) * 100
    print("  FP walk captured \(fpNofp.frames)/\(fpNormal.frames) frames on no-FP stack (\(String(format: "%.0f", loss))% loss)")

    if ksNofp.frames > fpNofp.frames {
        print("  KSCrash recovered \(ksNofp.frames) frames on no-FP stack (vs \(fpNofp.frames) from FP walk)")
        print("  → KSCrash fallback provides value")
    } else {
        print("  KSCrash also captured only \(ksNofp.frames) frames (it also uses FP walking)")
        print("  → KSCrash fallback does NOT help for frameless code")
        print("  → A DWARF-based unwinder would be needed for true frameless support")
    }
} else {
    print("  FP walk captured same frames on both stacks (-fomit-frame-pointer had no effect)")
    print("  → KSCrash fallback would NOT activate on this architecture")
}

print()

#else
print("Benchmarks not available on watchOS")
#endif
