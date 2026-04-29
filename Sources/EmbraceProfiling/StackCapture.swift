//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
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

/// Captures a stack trace from a running thread.
///
/// Suspends the target thread, walks its stack, then resumes the thread.
///
/// Tries fast frame-pointer walking first. If that yields fewer than ``minFPFrames``
/// frames, falls back to KSCrash's `captureBacktrace` unwinder.
///
/// Note: KSCrash will support walking a stack without a FP in the next release.
///
/// - Parameters:
///   - thread: The Mach thread port of the thread to capture.
///   - maxFrames: Maximum number of frames to capture.
/// - Returns: A tuple containing the array of return addresses and the method used to capture them.
func captureStack(thread: thread_t, maxFrames: Int = 512) -> (frames: [UInt], method: StackUnwindMethod) {
    var fpFrames = [UInt](repeating: 0, count: maxFrames)
    var ksFrames = [UInt](repeating: 0, count: maxFrames)
    let pthread = pthread_from_mach_thread_np(thread)

    // Resolve stack bounds before suspending — pthread APIs are not async-safe.
    var stackBottom: UnsafeRawPointer? = nil
    var stackTop: UnsafeRawPointer? = nil
    if let pth = pthread {
        let top = pthread_get_stackaddr_np(pth)
        let size = pthread_get_stacksize_np(pth)
        stackTop = UnsafeRawPointer(top)
        stackBottom = UnsafeRawPointer(top - size)
    }

    guard thread_suspend(thread) == KERN_SUCCESS else {
        return ([], .failed)
    }

    // Only async-safe things allowed between suspend and resume.

    var fpCount = 0
    let fpSuccess: Bool
    if let bottom = stackBottom, let top = stackTop {
        fpSuccess = emb_stack_walk(thread, bottom, top, &fpFrames, maxFrames, &fpCount)
    } else {
        fpSuccess = false
    }

    // Fall back to KSCrash's unwinder if FP walking didn't produce enough
    // frames.
    //
    // `captureBacktrace` currently does its own suspend/resume of the
    // target thread, but since Mach uses a suspend count, the nested
    // suspend/resume just bumps the count to 2 and back to 1,
    // and then our outer resume below takes it to 0. A future KSCrash
    // release will expose a variant that skips the extra dance.
    // (see kstenerud/KSCrash#816).
    var ksCount: Int32 = 0
    if (!fpSuccess || fpCount < minFPFrames), let pthread = pthread {
        ksCount = captureBacktrace(thread: pthread, addresses: &ksFrames, count: Int32(maxFrames))
    }

    thread_resume(thread)

    // Safe to allocate again.
    if fpSuccess && fpCount >= minFPFrames {
        return (Array(fpFrames[0..<fpCount]), .framePointer)
    }
    if ksCount > 0 {
        return (Array(ksFrames[0..<Int(ksCount)]), .kscrash)
    }
    if fpSuccess && fpCount > 0 {
        return (Array(fpFrames[0..<fpCount]), .framePointerPartial)
    }
    return ([], .failed)
}

#endif
