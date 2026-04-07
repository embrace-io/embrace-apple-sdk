//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

// CADisplayLink is not available on watchOS, so hang capture based on frame rate
// is not supported on that platform. watchOS support will be revisited in the future.
#if !os(watchOS)

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

        // No monitor when debugger is attached.
        if isDebuggerAttached() && ProcessInfo.processInfo.environment["EMBAllowWatchdogInDebugger"] != "1" {
            logger?.warning(
                "[FrameRateMonitor] Disabled because a debugger is attached. Set the env var EMBAllowWatchdogInDebugger=1 to enable in debug mode.")
            return
        }

        // Since we use `limits.hangPerSession` as a gate for the monitor,
        // we need to wait until the remote config is actually loaded from disk
        // which happens just before this call.
        let currentLimits = limits
        let monitor: FrameRateMonitor? = currentLimits.hangPerSession > 0
            ? FrameRateMonitor(threshold: currentLimits.hangThreshold)
            : nil
        monitor?.hangObserver = self
        monitor?.logger = logger
        limitData.withLock { $0.watchdog = monitor }
    }

    public override func onSessionStart(_ session: any EmbraceSession) {
        limitData.withLock { $0.hangsInSessionCount = 0 }
    }

    public override func onSessionWillEnd(_ session: any EmbraceSession) {
        let value = limitData.withLock { $0.hangsInSessionCount }
        try? Embrace.client?.metadata.updateProperty(key: SpanSemantics.Hang.name, value: "\(value)")
    }

    public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
        let newLimits = config.hangLimits
        let monitorNeedsUpdate = limitData.withLock {
            let changed = $0.limits.hangThreshold != newLimits.hangThreshold
                || ($0.limits.hangPerSession == 0) != (newLimits.hangPerSession == 0)
            $0.limits = newLimits
            return changed
        }
        if monitorNeedsUpdate {
            let monitor: FrameRateMonitor? = newLimits.hangPerSession > 0
                ? FrameRateMonitor(threshold: newLimits.hangThreshold)
                : nil
            monitor?.hangObserver = self
            monitor?.logger = logger
            limitData.withLock { $0.watchdog = monitor }
        }
    }

    private var mainThread: pthread_t

    struct MutableLimitData {
        var limits: HangLimits = HangLimits()
        var hangsInSessionCount: UInt = 0
        var watchdog: FrameRateMonitor?
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

extension HangCaptureService: HangObserver {

    // Hang span documented here:
    // https://www.notion.so/embraceio/ANRs-1d77e3c9985281c58765d8c622443e2c

    public func hangStarted(at: Date, duration: TimeInterval) {

        logger?.debug("[FrameRateMonitor] Hang started, at \(at) after \(Int(duration * 1000)) ms")

        if limits.reportsWatchdogEvents {
            NotificationCenter.default.post(
                name: .hangEventStarted,
                object: WatchdogEvent(timestamp: at, duration: duration)
            )
        }

        let canStart = limitData.withLock {
            guard $0.hangsInSessionCount < $0.limits.hangPerSession else {
                return false
            }
            $0.hangsInSessionCount += 1
            return true
        }
        guard canStart else {
            let limitData = limitData.withLock { $0 }
            logger?.warning(
                "[FrameRateMonitor] Dropping hang due to surpassing limit, \(limitData.hangsInSessionCount) of \(limitData.limits.hangPerSession)")
            return
        }

        // build the span
        let unixNano = UInt64((at.timeIntervalSince1970 * 1_000_000_000).rounded())
        guard
            let builder = buildSpan(
                name: SpanSemantics.Hang.name,
                type: SpanType.hang,
                attributes: [
                    SpanSemantics.Hang.keyLastKnownTimeUnixNano: "\(unixNano)",
                    SpanSemantics.Hang.keyIntervalCode: "0",
                    SpanSemantics.Hang.keyThreadPriority: "0"
                ]
            )
        else {
            logger?.warning("[FrameRateMonitor] failed to create emb-thread-blockage span.")
            return
        }

        // Capture a single retroactive backtrace of the main thread.
        let pre = Date()
        let backtrace = EmbraceBacktrace.backtrace(of: mainThread, threadIndex: 0)
        let post = Date()

        spanQueue.async { [self] in
            span = builder
                .setStartTime(time: at)
                .startSpan()
            addSamplingSpanEvent(
                time: at,
                backtrace: backtrace,
                overhead: Int(post.timeIntervalSince(pre) * 1_000_000_000)
            )
        }
    }

    public func hangEnded(at: Date, duration: TimeInterval) {
        logger?.debug("[FrameRateMonitor] Hang ended at \(at) after \(Int(duration * 1000)) ms")

        if limits.reportsWatchdogEvents {
            NotificationCenter.default.post(
                name: .hangEventEnded,
                object: WatchdogEvent(timestamp: at, duration: duration)
            )
        }

        spanQueue.async { [self] in
            span?.end(time: at)
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

#endif
