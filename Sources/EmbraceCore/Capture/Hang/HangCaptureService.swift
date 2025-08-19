//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

/// Service that generates OpenTelemetry span events for hangs.
@objc(EMBHangCaptureService)
public final class HangCaptureService: CaptureService {

    public init(
        limits: HangLimits = HangLimits()
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.mainThread = pthread_self()
        self.limitData = EmbraceMutex(LimitData(limits: limits))
        super.init()
    }

    public override func onInstall() {
        // Since we use `limits.hangPerSession` as a gate for the watchdog,
        // we need to wait until the remote config is actually loaded from disk
        // which happens just before this call.
        watchdog = limits.hangPerSession > 0 ? HangWatchdog() : nil
        watchdog?.hangObserver = self
        watchdog?.logger = logger
    }

    public override func onSessionStart(_ session: any EmbraceSession) {
        limitData.withLock { $0.hangsInSessionCount = 0 }
    }

    public override func onSessionWillEnd(_ session: any EmbraceSession) {
        let value = limitData.withLock { $0.hangsInSessionCount }
        try? Embrace.client?.metadata.updateProperty(key: "emb-thread-blockage", value: "\(value)")
    }

    public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
        self.limitData.withLock { $0.limits = config.hangLimits }
    }

    private var mainThread: pthread_t
    private var watchdog: HangWatchdog?
    private let queue = DispatchQueue(label: "io.embrace.hang.service")

    private var span: OpenTelemetryApi.Span?

    struct LimitData {
        var limits: HangLimits = HangLimits()
        var hangsInSessionCount: UInt = 0
        var samplesInHangCount: UInt = 0
    }
    var limitData: EmbraceMutex<LimitData>

    public var limits: HangLimits {
        get {
            limitData.withLock { $0.limits }
        }
        set {
            limitData.withLock { $0.limits = newValue }
        }
    }
}

extension HangCaptureService: HangObserver {

    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c

    public func hangStarted(at: NanosecondClock, duration: NanosecondClock) {

        logger?.debug("[Watchdog] Hang started, at \(at.date) after waiting \(duration.uptime.milliseconds) ms")

        // Keep tabs on how many hang spans we've created
        guard
            limitData.withLock({
                $0.samplesInHangCount = 0
                $0.hangsInSessionCount += 1
                return $0.hangsInSessionCount <= $0.limits.hangPerSession
            })
        else {
            let limitData = self.limitData.withLock { $0 }
            logger?.warning(
                "[Watchdog] Dropping hang due to surpassing limit, \(limitData.hangsInSessionCount) of \(limitData.limits.hangPerSession)")
            return
        }

        // build the span
        guard
            let builder = buildSpan(
                name: "emb-thread-blockage",
                type: SpanType(primary: .performance, secondary: "thread_blockage"),
                attributes: [:]
            )
        else {
            logger?.warning("[Watchdog] failed to create emb-thread-blockage span.")
            return
        }

        queue.async { [self] in
            span =
                builder
                .setStartTime(time: at.date)
                .setAttribute(key: "last_known_time_unix_nano", value: .int(Int(at.realtime)))
                .setAttribute(key: "interval_code", value: .int(0))
                .setAttribute(key: "thread_priority", value: .int(0))
                .startSpan()
        }
    }

    public func hangUpdated(at: NanosecondClock, duration: NanosecondClock) {
        logger?.debug("[Watchdog] Hang for \(duration.uptime.milliseconds) ms")

        guard
            limitData.withLock({
                $0.samplesInHangCount += 1
                return $0.samplesInHangCount <= $0.limits.samplesPerHang
            })
        else {
            return
        }

        // Are we over the limit or don't have a span for some reason?
        guard let span else {
            return
        }

        // Capture the stack now
        let pre = NanosecondClock.current
        // TODO: Implement stacktrace collection here. Currently, frames is empty and stacktraces are not captured.
        let frames: [String] = []
        let post = NanosecondClock.current

        // process it later
        queue.async {

            let stackString = frames.joined()

            span.addEvent(
                name: "perf.thread_blockage_sample",
                attributes: [
                    "sample_overhead": .int(Int(post.monotonic - pre.monotonic)),
                    "frame_count": .int(frames.count),
                    "thread_state": .string("BLOCKED"),
                    "sample_code": .int(0),
                    "stacktrace": .string(stackString)
                ],
                timestamp: at.date
            )
        }
    }

    public func hangEnded(at: NanosecondClock, duration: NanosecondClock) {
        logger?.debug("[Watchdog] Hang ended at \(at.date) after \(duration.uptime.milliseconds) ms")

        // Are we over the limit or don't have a span for some reason?
        guard let span else {
            return
        }

        queue.async {
            span.end(time: at.date)
            self.span = nil
        }
    }
}
