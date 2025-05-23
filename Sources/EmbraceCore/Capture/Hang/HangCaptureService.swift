//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import UIKit
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceSemantics
#endif
import OpenTelemetryApi

/// Service that generates OpenTelemetry span events for hangs.
@objc(EMBHangCaptureService)
public final class HangCaptureService: CaptureService {
    
    public init(watchdog: HangWatchdog = HangWatchdog()) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.watchdog = watchdog
        self.mainThread = pthread_self()
        super.init()
        self.watchdog.hangObserver = self
    }

    private var mainThread: pthread_t
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
        let frames = EmbraceBacktrace.backtrace(of: self.mainThread).threads.first?.frames ?? []
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

private func nanosecondsToSeconds(_ nanos: UInt64) -> Double {
    Double(nanos) / Double(NSEC_PER_SEC)
}

private func nanosecondsToMilliseconds(_ nanos: UInt64) -> UInt64 {
    nanos / NSEC_PER_MSEC
}
