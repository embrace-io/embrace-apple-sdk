//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

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

    public override func onInstall() {
        watchdog.logger = logger
    }

    private var mainThread: pthread_t
    private var watchdog: HangWatchdog
    private var anrSpan: OpenTelemetryApi.Span?
    private var hangSpan: OpenTelemetryApi.Span?
}

extension HangCaptureService: HangObserver {

    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c

    public func hangStarted(at time: UInt64, duration: UInt64) {

        logger?.debug("[Watchdog] Hang started, at \(nanosecondsToMilliseconds(duration)) ms")
        let startTime = Date(timeIntervalSinceNow: -nanosecondsToSeconds(duration))

        // ANR span (ewww!)
        guard
            let builder = buildSpan(
                name: "emb-thread-blockage",
                type: SpanType(primary: .performance, secondary: "thread_blockage"),
                attributes: [:]
            )
        else {
            logger?.warning("[Watchdog] failed to create anr span.")
            return
        }

        builder
            .setStartTime(time: startTime)
            .setAttribute(key: "last_known_time_unix_nano", value: .int(Int(time)))  // this is not unix time, it's uptime raw
            .setAttribute(key: "interval_code", value: .int(0))

        anrSpan = builder.startSpan()

        // Hang span :)
        guard
            let builder = buildSpan(
                name: "hang",
                type: .performance,
                attributes: [:]
            )
        else {
            logger?.warning("[Watchdog] failed to create hang span.")
            return
        }

        builder
            .setStartTime(time: startTime)

        hangSpan = builder.startSpan()
    }

    public func hangUpdated(at time: UInt64, duration: UInt64) {
        logger?.debug("[Watchdog] Hang for \(nanosecondsToMilliseconds(duration)) ms")

        /**
         * This is basically what we'll do when profiling.
        
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
                    // frames.map { String($0.address) }.joined(separator: ",")
                    stackString
                ),
                "sample_overhead": .int(Int(post - pre)),
                LogSemantics.keyStackTrace: .string("")
            ]
        )
         */
    }

    public func hangEnded(at time: UInt64, duration: UInt64) {
        logger?.debug("[Watchdog] Hang ended at \(nanosecondsToMilliseconds(duration)) ms")

        let now = Date()

        anrSpan?.end(time: now)
        anrSpan = nil

        hangSpan?.end(time: now)
        hangSpan = nil
    }
}

private func nanosecondsToSeconds(_ nanos: UInt64) -> Double {
    Double(nanos) / Double(NSEC_PER_SEC)
}

private func nanosecondsToMilliseconds(_ nanos: UInt64) -> UInt64 {
    nanos / NSEC_PER_MSEC
}
