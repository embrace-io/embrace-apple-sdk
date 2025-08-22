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

    public init(
        watchdog: HangWatchdog = HangWatchdog(),
        hangPerSessionLimit: UInt = 200,
        samplesPerHangLimit: UInt = 200
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.watchdog = watchdog
        self.mainThread = pthread_self()
        self.limitHangPerSession = hangPerSessionLimit
        self.limitSamplesPerHang = samplesPerHangLimit
        super.init()
        self.watchdog.hangObserver = self
    }

    public override func onInstall() {
        watchdog.logger = logger
    }

    public override func onSessionStart(_ session: any EmbraceSession) {
        hangsInSessionCount = 0
    }

    public override func onSessionWillEnd(_ session: any EmbraceSession) {
        try? Embrace.client?.metadata.updateProperty(key: "emb-thread-blockage", value: "\(hangsInSessionCount)")
    }

    private var mainThread: pthread_t
    private var watchdog: HangWatchdog
    private let queue = DispatchQueue(label: "io.embrace.hang.service")

    private var span: OpenTelemetryApi.Span?

    private var hangsInSessionCount: UInt = 0
    private var limitHangPerSession: UInt

    private var samplesInHangCount: UInt = 0
    private var limitSamplesPerHang: UInt
}

extension HangCaptureService: HangObserver {

    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c

    public func hangStarted(at: NanosecondClock, duration: NanosecondClock) {

        logger?.debug("[Watchdog] Hang started, at \(at.date) after waiting \(duration.uptime.milliseconds) ms")

        // Keep tabs on how many hang spans we've created
        samplesInHangCount = 0
        hangsInSessionCount += 1
        guard hangsInSessionCount <= limitHangPerSession else {
            logger?.warning(
                "[Watchdog] Dropping hang due to surpassing limit, \(hangsInSessionCount) of \(limitHangPerSession)")
            return
        }

        // build the span
        guard
            let builder = buildSpan(
                name: "emb-thread-blockage",
                type: .ux,  // perf.thread_blockage
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

        samplesInHangCount += 1
        guard samplesInHangCount <= limitSamplesPerHang else {
            return
        }

        // Are we over the limit or don't have a span for some reason?
        guard let span else {
            return
        }

        // Capture the stack now
        let pre = NanosecondClock.current
        let frames: [String] = []  // EmbraceBacktrace.backtrace(of: self.mainThread).threads.first?.frames ?? []
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
