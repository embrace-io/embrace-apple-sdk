//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

// CADisplayLink is unavailable on watchOS, and on macOS it can only be
// obtained via NSView/NSWindow/NSScreen.displayLink(target:selector:)
// rather than constructed standalone — so frame-rate based hang capture
// is not supported on those platforms.
#if !os(watchOS) && !os(macOS)

    /// Service that generates OpenTelemetry span events for hangs.
    public final class HangCaptureService: CaptureService {

        /// Creates a new `HangCaptureService` with the given limits.
        /// - Parameter limits: The hang detection limits applied by the service.
        public init(
            limits: HangLimits = HangLimits()
        ) {
            self.limitData = EmbraceMutex(MutableLimitData(limits: limits))
            super.init()
        }

        public override func onStart() {

            // No monitor when debugger is attached.
            if isDebuggerAttached() && ProcessInfo.processInfo.environment["EMBAllowWatchdogInDebugger"] != "1" {
                logger?.warning(
                    "[FrameRateMonitor] Disabled because a debugger is attached. Set the env var EMBAllowWatchdogInDebugger=1 to enable in debug mode.")
                return
            }

            // `limits.hangPerSession` gates the monitor, and the remote config is loaded from disk
            // before the service is installed and started, so `limits` is authoritative here.
            activate(with: limits)
        }

        public override func onStop() {
            // Tear down the detector and sampler so no poll thread or CADisplayLink outlives an SDK
            // stop. Releasing the monitor invalidates its CADisplayLink via `FrameRateMonitor.deinit`.
            let sampler = limitData.withLock { data -> MainThreadStackSampler? in
                let previous = data.sampler
                data.watchdog = nil
                data.sampler = nil
                return previous
            }
            sampler?.stop()
        }

        /// Builds a fresh detector + sampler for `limits`, starts the sampler, and swaps them in for
        /// the previous pair (which is stopped and released). The swap is committed under the lock
        /// only if the service is still active; if a concurrent `onStop()` raced in between building
        /// and storing, the freshly built pair is torn down instead — so no poll thread or
        /// CADisplayLink outlives the stop.
        private func activate(with limits: HangLimits) {
            let (monitor, sampler) = makeMonitorAndSampler(for: limits)
            sampler?.start()
            let (oldSampler, stored) = limitData.withLock { data -> (MainThreadStackSampler?, Bool) in
                guard state.load(order: .acquire) == .active else { return (nil, false) }
                let previous = data.sampler
                data.watchdog = monitor
                data.sampler = sampler
                return (previous, true)
            }
            oldSampler?.stop()
            if !stored {
                sampler?.stop()  // service stopped mid-build; release the pair we just started
            }
        }

        /// Builds the detector + during-block sampler pair for `limits`, or `(nil, nil)` when hangs
        /// are disabled. The sampler is returned un-started (the caller owns `start()`/`stop()`); the
        /// monitor begins observing as soon as it is constructed — `FrameRateMonitor.init` adds its
        /// `CADisplayLink` to the main run loop — and stops when it is released.
        private func makeMonitorAndSampler(
            for limits: HangLimits
        ) -> (FrameRateMonitor?, MainThreadStackSampler?) {
            guard limits.hangPerSession > 0 else { return (nil, nil) }
            let monitor = FrameRateMonitor(threshold: limits.hangThreshold)
            monitor.hangObserver = self
            monitor.logger = logger
            let sampler = StallTriggeredSampler(
                triggerThreshold: limits.sampleTriggerThreshold,
                pollInterval: limits.samplePollInterval,
                logger: logger
            )
            return (monitor, sampler)
        }

        public override func onSessionStart() {
            limitData.withLock { $0.hangsInSessionCount = 0 }
        }

        public override func onSessionWillEnd() {
            let value = limitData.withLock { $0.hangsInSessionCount }
            Embrace.client?.metadata.updateProperty(key: SpanSemantics.Hang.name, value: "\(value)")
        }

        public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
            let newLimits = config.hangLimits
            let monitorNeedsUpdate = limitData.withLock {
                let changed =
                    $0.limits.hangThreshold != newLimits.hangThreshold
                    || ($0.limits.hangPerSession == 0) != (newLimits.hangPerSession == 0)
                    || $0.limits.sampleTriggerThreshold != newLimits.sampleTriggerThreshold
                    || $0.limits.samplePollInterval != newLimits.samplePollInterval
                $0.limits = newLimits
                return changed
            }
            // Only rebuild the live detector/sampler while active. If the service isn't running the
            // new limits are stored above and applied the next time `onStart()` runs — a config
            // update must never spin up a poll thread on a stopped service.
            guard monitorNeedsUpdate, state.load(order: .acquire) == .active else { return }
            activate(with: newLimits)
        }

        struct MutableLimitData {
            var limits: HangLimits = HangLimits()
            var hangsInSessionCount: UInt = 0
            var watchdog: FrameRateMonitor?
            var sampler: MainThreadStackSampler?
        }
        let limitData: EmbraceMutex<MutableLimitData>

        private let spanQueue = DispatchQueue(label: "io.embrace.hang.service")
        private var span: EmbraceSpan?

        /// The hang detection limits currently applied by the service.
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

            // No stack is captured here. The hang stack is attached at `hangEnded` from the
            // during-block sampler; a retroactive on-main capture at this point would walk the
            // display-link servicing path (CADisplayLink only fires after main unblocks), not the
            // code that actually hung.
            spanQueue.async { [self] in
                span = try? otel?.createInternalSpan(
                    name: SpanSemantics.Hang.name,
                    type: .hang,
                    startTime: at,
                    attributes: [
                        SpanSemantics.Hang.keyLastKnownTimeUnixNano: "\(unixNano)",
                        SpanSemantics.Hang.keyIntervalCode: "0",
                        SpanSemantics.Hang.keyThreadPriority: "0"
                    ])
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

            // Reconcile the CADisplayLink-confirmed hang with the sampler's during-block snapshots.
            // `duration` is a clock-agnostic interval, so subtracting it from a fresh
            // CLOCK_MONOTONIC_RAW reading (taken here on main, ≈ real hang end) yields the window in
            // the sampler's own clock. The during-block sample was taken at ≈ start + trigger, so it
            // lands inside; a small tolerance absorbs callback latency.
            let tolerance: UInt64 = 20_000_000  // 20 ms
            let endMono = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
            let durationNanos = UInt64((duration * 1_000_000_000).rounded())
            let startMono = endMono > durationNanos + tolerance ? endMono &- durationNanos &- tolerance : 0
            // Take the earliest during-block sample in the window — closest to where the block began.
            let (hasSampler, sample) = limitData.withLock { data -> (Bool, MainThreadStackSample?) in
                let sampler = data.sampler
                return (sampler != nil, sampler?.samples(in: startMono...endMono).first)
            }
            let sampleTime = at.addingTimeInterval(-duration)

            spanQueue.async { [self] in
                if let sample {
                    addSamplingSpanEvent(
                        time: sampleTime,
                        backtrace: sample.backtrace,
                        overhead: Int(sample.overhead)
                    )
                } else {
                    // Emit the span with no stack — an honest "no trace" beats the old misleading one —
                    // but log why, so an empty stack is distinguishable from missing hang data.
                    logger?.debug(
                        "[Hang] confirmed hang emitted with no during-block stack "
                            + "(\(hasSampler ? "sampler active, no sample landed in the window" : "no active sampler")).")
                }
                span?.end(endTime: at)
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
                logger?.warning(
                    "[Hang] captured a during-block backtrace but all frames were dropped "
                        + "(frameCount = 0) — symbolication resolved nothing.")
                return
            }

            span.addEvent(
                name: SpanEventSemantics.Hang.name,
                type: .hang,
                timestamp: time,
                attributes: [
                    SpanEventSemantics.Hang.keySampleOverhead: overhead,
                    SpanEventSemantics.Hang.keyFrameCount: stack.frameCount,
                    LogSemantics.keyStackTrace: stack.stackString
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
