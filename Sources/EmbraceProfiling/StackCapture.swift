//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

import Darwin
import EmbraceProfilingSampler

#if canImport(KSCrash)
    import KSCrash
#else
    import KSCrashRecording
#endif

/// Minimum number of frames from frame-pointer walking to consider the walk
/// successful. Below this threshold we fall back to KSCrash's unwinder.
private let minFPFrames = 3

/// Captures a stack trace from a suspended thread.
///
/// Uses fast frame-pointer walking first. If that yields fewer than
/// ``minFPFrames`` frames, falls back to KSCrash's `captureBacktrace`
/// unwinder.
///
/// Note: KSCrash will support walking a stack without a FP in the next release.
///
/// The thread **must** already be suspended before calling this function.
///
/// - Parameters:
///   - thread: The Mach thread port of the suspended thread.
///   - maxFrames: Maximum number of frames to capture.
/// - Returns: A tuple containing the array of return addresses and the method used to capture them.
func captureStack(thread: thread_t, maxFrames: Int = 512) -> (frames: [UInt], method: StackUnwindMethod) {
    // Try fast frame-pointer walking first.
    var frames = [UInt](repeating: 0, count: maxFrames)
    var count = 0
    let success = emb_stack_walk(thread, &frames, maxFrames, &count)

    if success && count >= minFPFrames {
        return (Array(frames[0..<count]), .framePointer)
    }

    // Fall back to KSCrash's unwinder.
    if let pthread = pthread_from_mach_thread_np(thread) {
        var ksFrames = [UInt](repeating: 0, count: maxFrames)
        let ksCount = captureBacktrace(thread: pthread, addresses: &ksFrames, count: Int32(maxFrames))

        if ksCount > 0 {
            return (Array(ksFrames[0..<Int(ksCount)]), .kscrash)
        }
    }

    // Just return whatever FP walking got us.
    if success && count > 0 {
        return (Array(frames[0..<count]), .framePointerPartial)
    }

    return ([], .framePointerPartial)
}

#endif
