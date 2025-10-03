//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

/// Service that generates OpenTelemetry span events for hangs.
public final class HangCaptureService: CaptureService {

    public init(
        limits: HangLimits = HangLimits()
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.mainThread = pthread_self()
        self.limitData = EmbraceMutex(MutableLimitData(limits: limits))
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

        try? Embrace.client?.metadata.updateProperty(
            key: SpanSemantics.ThreadBlockage.name,
            value: "\(value)"
        )
    }

    public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
        self.limitData.withLock { $0.limits = config.hangLimits }
    }

    private var mainThread: pthread_t
    private var watchdog: HangWatchdog?

    struct MutableLimitData {
        var limits: HangLimits = HangLimits()
        var hangsInSessionCount: UInt = 0
        var samplesInHangCount: UInt = 0
    }
    let limitData: EmbraceMutex<MutableLimitData>

    private let spanQueue = DispatchQueue(label: "io.embrace.hang.service")
    private var span: EmbraceSpan?

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

    func hangStarted(at: NanosecondClock, duration: NanosecondClock) {

        logger?.debug("[Watchdog] Hang started, at \(at.date) after waiting \(duration.uptime.milliseconds) ms")

        // Keep tabs on how many hang spans we've created
        let sampleInfo = limitData.withLock {
            $0.samplesInHangCount = 0
            $0.hangsInSessionCount += 1
            return (canStart: $0.hangsInSessionCount <= $0.limits.hangPerSession, canSample: $0.samplesInHangCount <= $0.limits.samplesPerHang)
        }
        guard sampleInfo.canStart else {
            let limitData = limitData.withLock { $0 }
            logger?.warning(
                "[Watchdog] Dropping hang due to surpassing limit, \(limitData.hangsInSessionCount) of \(limitData.limits.hangPerSession)")
            return
        }

        // build the span
        spanQueue.async { [self] in
            do {
                span = try otel?.createInternalSpan(
                    name: SpanSemantics.ThreadBlockage.name,
                    type: .threadBlockage,
                    startTime: at.date,
                    attributes: [
                        SpanSemantics.ThreadBlockage.keyLastKnownTime: String(at.realtime),
                        SpanSemantics.ThreadBlockage.keyIntervalCode: "0",
                        SpanSemantics.ThreadBlockage.keyThreadPriority: "0"
                    ]
                )
            } catch {
                logger?.warning("[Watchdog] failed to create emb-thread-blockage span.")
            }

            // Capture the stack now
            let pre = NanosecondClock.current
            let backtrace = EmbraceBacktrace.backtrace(of: mainThread, suspendingThreads: true)
            let post = NanosecondClock.current

            if sampleInfo.canSample {
                addSamplingSpanEvent(time: at.date, backtrace: backtrace, overhead: Int(post.monotonic - pre.monotonic))
            }
        }
    }

    func hangUpdated(at: NanosecondClock, duration: NanosecondClock) {
        logger?.debug("[Watchdog] Hang for \(duration.uptime.milliseconds) ms")

        guard
            limitData.withLock({
                $0.samplesInHangCount += 1
                return $0.hangsInSessionCount <= $0.limits.hangPerSession && $0.samplesInHangCount <= $0.limits.samplesPerHang
            })
        else {
            return
        }

        // Capture the stack now
        let pre = NanosecondClock.current
        let backtrace = EmbraceBacktrace.backtrace(of: mainThread, suspendingThreads: true)
        let post = NanosecondClock.current

        // process it later
        spanQueue.async { [self] in
            addSamplingSpanEvent(time: at.date, backtrace: backtrace, overhead: Int(post.monotonic - pre.monotonic))
        }
    }

    func hangEnded(at: NanosecondClock, duration: NanosecondClock) {
        logger?.debug("[Watchdog] Hang ended at \(at.date) after \(duration.uptime.milliseconds) ms")

        spanQueue.async { [self] in
            span?.end(endTime: at.date)
            span = nil
        }
    }

    private func addSamplingSpanEvent(time: Date, backtrace: EmbraceBacktrace, overhead: Int) {

        dispatchPrecondition(condition: .onQueue(spanQueue))

        guard let span else {
            return
        }

        let stack = processBacktrace(backtrace)
        guard stack.frameCount > 0 else {
            return
        }

        try? span.addEvent(
            name: SpanEventSemantics.ThreadBlockage.name,
            type: .threadBlockage,
            timestamp: time,
            attributes: [
                SpanEventSemantics.ThreadBlockage.keySampleOverhead: String(overhead),
                SpanEventSemantics.ThreadBlockage.keyFrameCount: String(stack.frameCount),
                SpanEventSemantics.ThreadBlockage.keyStacktrace: stack.stackString
            ]
        )
    }

    private func processBacktrace(_ backtrace: EmbraceBacktrace) -> (frameCount: Int, stackString: String) {

        dispatchPrecondition(condition: .onQueue(spanQueue))

        let frames: [[String: Any]]
        if let thread = backtrace.threads.first {
            frames = thread.frames(symbolicated: true).compactMap { $0.asProcessedFrame() }
        } else {
            frames = []
        }

        let frameCount: Int
        let stackString: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: frames, options: [])
            stackString = jsonData.base64EncodedString()
            frameCount = frames.count
        } catch let exception {
            stackString = ""
            frameCount = 0
            Embrace.logger.error("Couldn't convert stack trace to json string: \(exception.localizedDescription)")
        }

        return (frameCount, stackString)
    }
}
