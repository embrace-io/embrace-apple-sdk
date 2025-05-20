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
        self.watchdog = watchdog
        super.init()
        self.watchdog.hangObserver = self
    }

    private var watchdog: HangWatchdog
    private var span: OpenTelemetryApi.Span? = nil
}

extension HangCaptureService: HangObserver {
    
    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c
    
    public func hangStarted(at time: UInt64, duration: UInt64) {
        
        logger?.debug("[AC:Watchdog] Hang started, for \(nanosecondsToMilliseconds(duration)) ms")
        
        span = buildSpan(
            name: "emb-thread-blockage",
            type: .performance,
            attributes: [
                "last_known_time_unix_nano": "\(time)",
                "interval_code": "0" // not sure what this is for
            ])?
            .startSpan()
    }
    
    public func hangUpdated(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang for \(nanosecondsToMilliseconds(duration)) ms")
        span?.addEvent(
            name: "perf.thread_blockage_sample",
            attributes: [
                "sample_overhead": .int(Int(time)),
                "frame_count": .int(0),
                "stacktrace": .string(""),
                "sample_code": .int(0),
                "thread_state": .string("BLOCKED"),
                "thread_priority": .int(0)
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
