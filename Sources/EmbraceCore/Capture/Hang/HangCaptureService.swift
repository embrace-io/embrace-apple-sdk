//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation
@preconcurrency import OpenTelemetryApi

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
        self.limitData = EmbraceMutex(MutableLimitData(limits: limits))
        super.init()
    }

    public override func onInstall() {

        // No watchdog when debugger is attached.
        if isDebuggerAttached() && ProcessInfo.processInfo.environment["EMBAllowWatchdogInDebugger"] != "1" {
            logger?.warning(
                "[Watchdog] Watchdog is disabled because a debugger is attached. Set the env var EMBAllowWatchdogInDebugger=1 to enable watchdog in debug mode.")
            return
        }

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
        try? Embrace.client?.metadata.updateProperty(key: SpanSemantics.Hang.name, value: "\(value)")
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
    private var span: OpenTelemetryApi.Span?

    public var limits: HangLimits {
        get {
            limitData.withLock { $0.limits }
        }
        set {
            limitData.withLock { $0.limits = newValue }
        }
    }
}

extension HangCaptureService: HangObserver, @unchecked Sendable {

    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c

    public func hangStarted(at: EmbraceClock, duration: EmbraceClock) {

        logger?.debug("[Watchdog] Hang started, at \(at.date) after waiting \(duration.uptime.millisecondsValue) ms")

        if limits.reportsWatchdogEvents {
            NotificationCenter.default.post(
                name: .hangEventStarted,
                object: WatchdogEvent(timestamp: at, duration: duration)
            )
        }

        // Keep tabs on how many hang spans we've created
        let sampleInfo = limitData.withLock {
            $0.samplesInHangCount = 1
            $0.hangsInSessionCount += 1
            return (
                canStart: $0.hangsInSessionCount <= $0.limits.hangPerSession,
                canSample: $0.samplesInHangCount <= $0.limits.samplesPerHang
            )
        }
        guard sampleInfo.canStart else {
            let limitData = limitData.withLock { $0 }
            logger?.warning(
                "[Watchdog] Dropping hang due to surpassing limit, \(limitData.hangsInSessionCount) of \(limitData.limits.hangPerSession)")
            return
        }

        // build the span
        guard
            let builder = buildSpan(
                name: SpanSemantics.Hang.name,
                type: SpanType.hang,
                attributes: [
                    SpanSemantics.Hang.keyLastKnownTimeUnixNano: "\(at.realtime)",
                    SpanSemantics.Hang.keyIntervalCode: "0",
                    SpanSemantics.Hang.keyThreadPriority: "0"
                ]
            )
        else {
            logger?.warning("[Watchdog] failed to create emb-thread-blockage span.")
            return
        }

        // Capture the stack now if we need to.
        var backtrace: EmbraceBacktrace? = nil
        var pre: EmbraceClock? = nil
        var post: EmbraceClock? = nil
        if sampleInfo.canSample {
            pre = EmbraceClock.current
            backtrace = EmbraceBacktrace.backtrace(of: mainThread, threadIndex: 0)
            post = EmbraceClock.current
        }

        spanQueue.async { [self] in
            span =
                builder
                .setStartTime(time: at.date)
                .startSpan()
            if let backtrace, let pre, let post {
                addSamplingSpanEvent(
                    time: at.date,
                    backtrace: backtrace,
                    overhead: Int((post.monotonic - pre.monotonic).nanosecondsValue)
                )
            }
        }
    }

    public func hangUpdated(at: EmbraceClock, duration: EmbraceClock) {
        logger?.debug("[Watchdog] Hang for \(duration.uptime.millisecondsValue) ms")

        if limits.reportsWatchdogEvents {
            NotificationCenter.default.post(
                name: .hangEventUpdated,
                object: WatchdogEvent(timestamp: at, duration: duration)
            )
        }

        guard
            limitData.withLock({
                $0.samplesInHangCount += 1
                return $0.hangsInSessionCount <= $0.limits.hangPerSession && $0.samplesInHangCount <= $0.limits.samplesPerHang
            })
        else {
            return
        }

        // Capture the stack now
        let pre = EmbraceClock.current
        let backtrace = EmbraceBacktrace.backtrace(of: mainThread, threadIndex: 0)
        let post = EmbraceClock.current

        // process it later
        spanQueue.async { [self] in
            addSamplingSpanEvent(
                time: at.date,
                backtrace: backtrace,
                overhead: Int((post.monotonic - pre.monotonic).nanosecondsValue)
            )
        }
    }

    public func hangEnded(at: EmbraceClock, duration: EmbraceClock) {
        logger?.debug("[Watchdog] Hang ended at \(at.date) after \(duration.uptime.millisecondsValue) ms")

        if limits.reportsWatchdogEvents {
            NotificationCenter.default.post(
                name: .hangEventEnded,
                object: WatchdogEvent(timestamp: at, duration: duration)
            )
        }

        spanQueue.async { [self] in
            span?.end(time: at.date)
            span = nil
        }
    }

    private func addSamplingSpanEvent(time: Date, backtrace: EmbraceBacktrace, overhead: Int) {

        dispatchPrecondition(condition: .onQueue(spanQueue))

        // Are we over the limit or don't have a span for some reason?
        guard let span else {
            return
        }

        let stack = processBacktrace(backtrace)
        guard stack.frameCount > 0 else {
            return
        }

        span.addEvent(
            name: SpanEventSemantics.Hang.name,
            attributes: [
                LogSemantics.keyEmbraceType: .string(SpanEventType.hang.rawValue),
                SpanEventSemantics.Hang.keySampleOverhead: .int(overhead),
                SpanEventSemantics.Hang.keyFrameCount: .int(stack.frameCount),
                LogSemantics.keyStackTrace: .string(stack.stackString)
            ],
            timestamp: time
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

@inline(__always)
private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var name: [Int32] = [
        CTL_KERN,
        KERN_PROC,
        KERN_PROC_PID,
        getpid()
    ]

    let result = name.withUnsafeMutableBufferPointer { namePtr -> Bool in
        return sysctl(namePtr.baseAddress, 4, &info, &size, nil, 0) == 0
    }

    guard result else { return false }
    return (info.kp_proc.p_flag & P_TRACED) != 0
}
