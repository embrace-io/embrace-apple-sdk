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
        bsg_mach_headers_initialize()
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
            //type: SpanType(primary: .performance, secondary: "thread_blockage"),
            type: .performance, // I want to see what i'm working on
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
        let frames = takeSnapshot()
        let stackString = String(data: (try? JSONEncoder().encode(frames)) ?? Data(), encoding: .utf8) ?? ""
        let post = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        
        span?.addEvent(
            name: "perf.thread_blockage_sample",
            attributes: [
                "sample_code": .int(0),
                "frame_count": .int(frames.count),
                "stacktrace": .string(
                    //frames.map { String($0.address) }.joined(separator: ",")
                    stackString
                ),
                "sample_overhead": .int(Int(post-pre)),
                LogSemantics.keyStackTrace: .string(""),
            ]
        )
    }
    
    public func hangEnded(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang ended at \(nanosecondsToMilliseconds(duration)) ms")
        span?.end()
        span = nil
    }
}

struct Frame: Codable {
    let address: UInt64
    
    let symbolAddress: UInt64
    let symbolName: String
    
    let imageUUID: String
    let imageName: String
    let imageSize: UInt64
}

// TODO: MIx this with EMBStackTraceProccessor
extension HangCaptureService {
    
    func takeSnapshot(symolicate: Bool = true) -> [Frame] {
        withSuspendedThreads {
            let entries = 512
            var addresses: [UInt] = Array(repeating: 0, count: 512)
            
            let frameCount = bsg_ksbt_backtraceThread(mainMachThread, &addresses, Int32(entries))
            
            var frames: [Frame] = []
            for index: Int in (0..<Int(frameCount)) {
                
                let address = addresses[index]

                let frame: Frame
                if symolicate {
                    var result: bsg_symbolicate_result = bsg_symbolicate_result()
                    bsg_symbolicate(address, &result)
                    
                    var uuid = if let img = result.image, let uuidt = img.pointee.uuid {
                        NSUUID(uuidBytes: uuidt).uuidString
                    } else { "" }
                    
                    frame = Frame(
                        address: UInt64(address),
                        symbolAddress: UInt64(result.function_address),
                        symbolName: result.function_name != nil ? String(cString: result.function_name) : "",
                        imageUUID: uuid,
                        imageName: result.image != nil ? String(cString: result.image.pointee.name) : "",
                        imageSize: result.image != nil ? result.image.pointee.imageSize : 0
                    )
                } else {
                    
                    frame = Frame(
                        address: UInt64(address),
                        symbolAddress: 0,
                        symbolName: "",
                        imageUUID: "",
                        imageName: "",
                        imageSize: 0
                    )
                }

                frames.append(frame)
            }
            
            return frames
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
