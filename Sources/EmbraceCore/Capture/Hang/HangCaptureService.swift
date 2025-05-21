//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import UIKit
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceSemantics
import EmbraceBugsnagTools
#endif
import OpenTelemetryApi
import Darwin
import MachO

#if canImport(KSCrashRecording)
import KSCrashRecording
#elseif canImport(KSCrash)
import KSCrash
#endif

/// Service that generates OpenTelemetry span events for hangs.
@objc(EMBHangCaptureService)
public final class HangCaptureService: CaptureService {
    
    public init(watchdog: HangWatchdog = HangWatchdog()) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.watchdog = watchdog
        self.mainPthread = pthread_self()
        self.mainMachThread = pthread_mach_thread_np(self.mainPthread)
        super.init()
        self.watchdog.hangObserver = self
    }

    private var mainPthread: pthread_t
    private var mainMachThread: mach_thread_flavor_t
    private var watchdog: HangWatchdog
    private var span: OpenTelemetryApi.Span? = nil
}

extension HangCaptureService: HangObserver {
    
    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c
    
    public func hangStarted(at time: UInt64, duration: UInt64) {
        
        logger?.debug("[AC:Watchdog] Hang started, at \(nanosecondsToMilliseconds(duration)) ms")

        guard let builder = buildSpan(
            name: "emb-thread-blockage",
            type: .performance,
            attributes: [:]
        ) else {
            logger?.warning("[AC:Watchdog] failed to create hang span.")
            return
        }
        
        builder
            // move the start time backwards to when the hang actually started
            .setStartTime(time: Date(timeIntervalSinceNow: -nanosecondsToSeconds(duration)))
            .setAttribute(key: "last_known_time_unix_nano", value: .int(Int(time)))
            .setAttribute(key: "interval_code", value: .int(0))
        
        span = builder.startSpan()
    }
    
    public func hangUpdated(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang for \(nanosecondsToMilliseconds(duration)) ms")
        
        let pre = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let snap = takeSnapshot()
        let post = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        
        span?.addEvent(
            name: "perf.thread_blockage_sample",
            attributes: [
                "sample_code": .int(0),
                "frame_count": .int(snap.count),
                "stacktrace": .string(snap.map{String($0)}.joined(separator: ",")),
                "sample_overhead": .int(Int(post-pre))
            ]
        )
    }
    
    public func hangEnded(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang ended at \(nanosecondsToMilliseconds(duration)) ms")
        span?.end()
        span = nil
    }
}

extension HangCaptureService {
    
    func takeSnapshot() -> [UInt] {
        withSuspendedThreads {
            let entries = 512
            var frames: [UInt] = Array(repeating: 0, count: 512)
            
            let entryCount = bsg_ksbt_backtraceThread(mainMachThread, &frames, Int32(entries))
            return Array(frames.prefix(Int(entryCount)))
        }
    }
    
    func withSuspendedThreads<T>(_ action: () -> T) -> T {
        onAllThreads(false)
        defer { onAllThreads(true) }
        return action()
    }
    
    private func onAllThreads(_ resume: Bool) {
        let task = mach_task_self_
        
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(task, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else {
            print("Failed to retrieve threads")
            return
        }
        
        let currentThread = pthread_mach_thread_np(pthread_self())
        
        for i in 0..<Int(threadCount) {
            let thread = threads[i]
            if thread != currentThread {
                let kr = resume ? thread_resume(thread) : thread_suspend(thread)
                if kr != KERN_SUCCESS {
                    print("Failed to modify thread \(thread): \(kr)")
                }
            }
        }
        
        // Deallocate the thread list
        let deallocSize = vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size)
        vm_deallocate(task, vm_address_t(UInt(bitPattern: threadList)), deallocSize)
    }
}

private func nanosecondsToSeconds(_ nanos: UInt64) -> Double {
    Double(nanos) / Double(NSEC_PER_SEC)
}

private func nanosecondsToMilliseconds(_ nanos: UInt64) -> UInt64 {
    nanos / NSEC_PER_MSEC
}
