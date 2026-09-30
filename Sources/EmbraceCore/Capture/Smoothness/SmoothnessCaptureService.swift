//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if DEBUG
    import os.signpost
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfiguration
    import EmbraceStorageInternal
#endif

// Frame timing relies on `CADisplayLink`, which is unavailable on watchOS and can't be constructed
// standalone on macOS.
#if !os(watchOS) && !os(macOS)

    /// Service that measures rendering smoothness and emits one `smoothness` span per foreground session
    /// part.
    ///
    /// The span opens when the foreground part starts, so it is persisted with that part's id right
    /// away, and ends just before the part's payload is built, carrying the part's frame count,
    /// dropped frames normalized to 60fps, hang count, and the most severe thermal state seen while it
    /// was open.
    ///
    /// When the app is terminated while a foreground part is open (e.g. swiped away from the app
    /// switcher), the part is never ended, so the span is ended on `willTerminate` instead and flushed
    /// to storage before the notification returns.
    ///
    /// A part that never ends cleanly otherwise (crash, watchdog or jetsam kill) leaves the span open in
    /// storage, and it is closed when the next launch recovers the session. It is flagged as failed only
    /// if a crash report was found. To keep its metrics, they are checkpointed onto the span every
    /// `checkpointInterval` while it is open, and the span carries `smoothness.complete = false` until
    /// it ends normally, so a recovered span can be told apart from a clean one.
    ///
    /// Installed by default but gated by remote config (`EmbraceConfigurable.isSmoothnessEnabled`). Until
    /// it's enabled for the device the service is dormant: no `CADisplayLink`, no spans.
    /// - Enabled while running: the pipeline starts, and the first span is the next foreground part's,
    ///   so no span covers only part of a part.
    /// - Disabled while running: the pipeline is torn down at once, and an open span ends with
    ///   `smoothness.end_reason = remote_disabled`.
    public final class SmoothnessCaptureService: CaptureService {

        public convenience override init() {
            self.init(ignoresRemoteConfig: false)
        }

        /// - Parameter ignoresRemoteConfig: Runs whether or not remote config enables smoothness. For
        ///   benchmarks, which must measure the service on devices outside the rollout.
        @_spi(Private)
        public convenience init(ignoresRemoteConfig: Bool) {
            self.init(
                currentSession: { Embrace.client?.sessionController.currentSession },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter,
                flushStorage: { Embrace.client?.storage.coreData.save(allowMainQueue: true) },
                ignoresRemoteConfig: ignoresRemoteConfig
            )
        }

        /// How often the open span's metrics are written to storage, so a part that is killed keeps
        /// them. Each checkpoint is a handful of asynchronous attribute writes, none on the frame path.
        static let defaultCheckpointInterval: TimeInterval = 15

        /// - Parameters:
        ///   - flushStorage: Blocks until pending storage writes, including the span's end, are on disk.
        ///   - thermalState: Reads the device's current thermal state.
        ///   - checkpointInterval: How often the open span's metrics are checkpointed. `0` disables it.
        ///   - debuggerAttached: Whether a debugger is attached. The service disables itself if so.
        ///   - environment: Checked for `EMBAllowWatchdogInDebugger=1`, which keeps it enabled anyway.
        ///   - ignoresRemoteConfig: Runs whether or not remote config enables smoothness.
        init(
            currentSession: @escaping () -> EmbraceSession?,
            notificationCenter: NotificationCenter,
            embraceNotificationCenter: NotificationCenter,
            flushStorage: @escaping () -> Void,
            thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
            checkpointInterval: TimeInterval = SmoothnessCaptureService.defaultCheckpointInterval,
            debuggerAttached: @escaping () -> Bool = isDebuggerAttached,
            environment: [String: String] = ProcessInfo.processInfo.environment,
            ignoresRemoteConfig: Bool = false
        ) {
            self.currentSession = currentSession
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter
            self.flushStorage = flushStorage
            self.thermalState = thermalState
            self.checkpointInterval = checkpointInterval
            self.debuggerAttached = debuggerAttached
            self.environment = environment
            self.ignoresRemoteConfig = ignoresRemoteConfig
            super.init()

            notificationCenter.addObserver(
                self,
                selector: #selector(appWillTerminate),
                name: SmoothnessCaptureService.willTerminateNotification,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(thermalStateDidChange),
                name: ProcessInfo.thermalStateDidChangeNotification,
                object: nil
            )
        }

        deinit {
            notificationCenter.removeObserver(self)
        }

        public override func onStart() {

            // Breakpoints and stepping would read as dropped frames.
            if isBlockedByDebugger {
                logger?.warning(
                    "[Smoothness] Disabled because a debugger is attached. Set the env var EMBAllowWatchdogInDebugger=1 to enable in debug mode.")
                return
            }

            // Opens a part that started before the tracker existed. That part isn't a partial one:
            // config applied before start comes from the cache, so the device was already in the
            // rollout when it started.
            onMain { [weak self] in self?.activate(opensCurrentPart: true) }
        }

        public override func onStop() {
            // A part still open here is closed with the frames counted so far, which ends its span
            // normally.
            tearDown(endReason: nil)
        }

        public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
            let hangThreshold = config.hangLimits.hangThreshold
            let isEnabled = config.isSmoothnessEnabled
            let (tracker, wasEnabled) = data.withLock { data -> (SmoothnessSessionTracker?, Bool) in
                let wasEnabled = data.isRemotelyEnabled
                data.hangThreshold = hangThreshold
                data.isRemotelyEnabled = isEnabled
                return (data.pipeline?.tracker, wasEnabled)
            }
            // Set outside `data`'s lock: the tracker calls back into it with its own lock held.
            tracker?.hangThreshold = hangThreshold

            // Before start, the value is only stored; `onStart()` applies it.
            guard !ignoresRemoteConfig, isEnabled != wasEnabled, state.load(order: .acquire) == .active else { return }

            if isEnabled {
                logger?.debug("[Smoothness] Enabled by remote config. Measuring from the next foreground part.")
                onMain { [weak self] in self?.activate(opensCurrentPart: false) }
            } else {
                logger?.debug("[Smoothness] Disabled by remote config.")
                tearDown(endReason: SpanSemantics.Smoothness.EndReason.remoteDisabled)
            }
        }

        /// Frames counted so far in the open foreground part, or `0` while the service isn't running
        /// (e.g. disabled because a debugger is attached) or no foreground part is open.
        ///
        /// SPI for benchmarks, to prove the service is active in the measured run. Reads the existing
        /// per-part count, so it adds nothing to the per-tick path.
        @_spi(Private)
        public var openPartFrameCount: Int {
            tracker?.openFrameCount ?? 0
        }

        // MARK: - Internal

        /// The per-tick hang ceiling currently applied, from `HangLimits.hangThreshold`.
        var hangThreshold: TimeInterval {
            data.withLock { $0.hangThreshold }
        }

        /// The live tracker, or `nil` while the service isn't running.
        var tracker: SmoothnessSessionTracker? {
            data.withLock { $0.pipeline?.tracker }
        }

        /// The live frame timing source, which owns the `CADisplayLink`, or `nil` while the service
        /// isn't running.
        var frameTimingSource: FrameTimingSource? {
            data.withLock { $0.pipeline?.source }
        }

        /// Writes the open span's metrics so far to it. No-ops if no span is open. Called by the
        /// checkpoint timer.
        func checkpoint() {
            tracker?.checkpoint(at: Date())
        }

        /// Builds the closure `FrameTimingSource` calls on every tick.
        ///
        /// In debug builds, `EMBSmoothnessSignposts=1` wraps each tick in an `os_signpost` interval
        /// (subsystem `io.embrace.sdk`, category `Smoothness`, name `Tick`) so its cost can be profiled
        /// in Instruments. The choice is made once here, so the per-tick path never branches on it.
        static func makeTickHandler(
            classifier: FrameDropClassifier,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> (FrameTimingSource.Tick) -> Void {
            let handler: (FrameTimingSource.Tick) -> Void = { [weak classifier] tick in
                classifier?.handle(tick)
            }

            #if DEBUG
                if environment["EMBSmoothnessSignposts"] == "1" {
                    let log = OSLog(subsystem: "io.embrace.sdk", category: "Smoothness")
                    return { tick in
                        os_signpost(.begin, log: log, name: "Tick")
                        handler(tick)
                        os_signpost(.end, log: log, name: "Tick")
                    }
                }
            #endif

            return handler
        }

        // MARK: - Private

        /// Whether a debugger keeps the service from running.
        private var isBlockedByDebugger: Bool {
            debuggerAttached() && environment["EMBAllowWatchdogInDebugger"] != "1"
        }

        /// Whether remote config lets the pipeline run. Call with `data`'s lock held.
        private func isRunnable(_ data: MutableData) -> Bool {
            ignoresRemoteConfig || data.isRemotelyEnabled
        }

        private func onMain(_ block: @escaping () -> Void) {
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        }

        /// Builds the timing source → classifier → tracker pipeline and stores it, but only if the
        /// service is active, remote config lets it run, and no pipeline is live. Must be called on the
        /// main thread.
        ///
        /// Every activation runs on main, so two can't interleave, and one that finds a live pipeline
        /// no-ops instead of replacing it. A teardown can still race in off main between the build and
        /// the store; the recheck under the lock then drops the new pipeline, which releases its
        /// CADisplayLink here on main.
        ///
        /// - Parameter opensCurrentPart: Whether to open the current foreground part now. `false` when
        ///   enabled partway through a part, which then gets no span.
        private func activate(opensCurrentPart: Bool) {
            guard !isBlockedByDebugger,
                data.withLock({ $0.pipeline == nil && isRunnable($0) })
            else {
                return
            }

            let classifier = FrameDropClassifier()
            let tracker = SmoothnessSessionTracker(
                classifier: classifier,
                hangThreshold: hangThreshold,
                currentSession: currentSession,
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            tracker.onSessionOpened = { [weak self] partId, startTime in
                self?.openSpan(partId: partId, startTime: startTime)
            }
            tracker.onSessionClosed = { [weak self] partId, stats in
                self?.endSpan(partId: partId, stats: stats)
            }
            tracker.onSessionCheckpoint = { [weak self] partId, stats in
                self?.checkpointSpan(partId: partId, stats: stats)
            }

            let source = FrameTimingSource()
            source.onTick = Self.makeTickHandler(classifier: classifier)

            // Before the store, so nothing can open the part in between; opens are delivered on main.
            if !opensCurrentPart {
                tracker.skipCurrentForegroundPart()
            }

            let stored = data.withLock { data -> Bool in
                guard state.load(order: .acquire) == .active, data.pipeline == nil, isRunnable(data) else { return false }
                data.pipeline = Pipeline(source: source, classifier: classifier, tracker: tracker)
                return true
            }

            // The first foreground part may have started before the tracker existed.
            if stored && opensCurrentPart {
                tracker.openCurrentForegroundPart()
            }
        }

        /// Takes the live pipeline out, closes its open part, and releases it on main.
        ///
        /// Releasing the pipeline invalidates its `CADisplayLink`, which must happen on main, where the
        /// display link delivers its ticks. The tracker is invalidated first, so a part start delivered
        /// before that release can't open a span.
        ///
        /// - Parameter endReason: Set on the open span as `smoothness.end_reason`, if any.
        private func tearDown(endReason: String?) {
            let pipeline = data.withLock { data -> Pipeline? in
                let previous = data.pipeline
                data.pipeline = nil
                if previous != nil {
                    data.openSpan?.endReason = endReason
                }
                return previous
            }
            guard let pipeline else { return }

            pipeline.tracker.invalidate(at: Date())

            if !Thread.isMainThread {
                DispatchQueue.main.async { withExtendedLifetime(pipeline) {} }
            }
        }

        private struct Pipeline {
            let source: FrameTimingSource
            let classifier: FrameDropClassifier
            let tracker: SmoothnessSessionTracker
        }

        private struct OpenSpan {
            let partId: EmbraceIdentifier
            let span: EmbraceSpan
            var peakThermalState: ProcessInfo.ThermalState
            /// Fires `checkpoint()` while the span is open. Cancelled when the span ends.
            let checkpointTimer: DispatchSourceTimer?
            /// Set when the span is ended early, e.g. by remote config. Written as `smoothness.end_reason`.
            var endReason: String?
        }

        private struct MutableData {
            var hangThreshold: TimeInterval = HangLimits().hangThreshold
            /// From `EmbraceConfigurable.isSmoothnessEnabled`. Off until a config says otherwise.
            var isRemotelyEnabled = false
            var pipeline: Pipeline?
            var openSpan: OpenSpan?
        }

        private let currentSession: () -> EmbraceSession?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private let flushStorage: () -> Void
        private let thermalState: () -> ProcessInfo.ThermalState
        private let checkpointInterval: TimeInterval
        private let debuggerAttached: () -> Bool
        private let environment: [String: String]
        private let ignoresRemoteConfig: Bool
        private let checkpointQueue = DispatchQueue(label: "io.embrace.smoothness.checkpoint", qos: .utility)

        /// Raw notification name to avoid a direct UIKit dependency.
        private static let willTerminateNotification =
            Notification.Name("UIApplicationWillTerminateNotification")

        /// Lock order: the tracker's lock, then this one. Never call into the tracker while holding it.
        private let data = EmbraceMutex(MutableData())

        /// `SessionController` doesn't end the session on terminate, so neither the part-will-end hook
        /// nor the payload build runs. End the span here with the frames counted so far.
        ///
        /// Span storage writes are queued asynchronously, and the process can be killed as soon as
        /// this returns, so they are flushed synchronously. A later will-end for the same part no-ops.
        @objc private func appWillTerminate() {
            guard let tracker, tracker.closeOpenSession(at: Date()) else { return }

            flushStorage()
        }

        /// Posted on an arbitrary thread. Only raises the open span's peak; never touches the tracker.
        @objc private func thermalStateDidChange() {
            let state = thermalState()
            data.withLock { data in
                data.openSpan?.peakThermalState.raise(to: state)
            }
        }

        /// Called on main with the tracker's lock held, so a concurrent close waits for the span.
        ///
        /// Created synchronously so the span is stamped with the part that is current right now. No
        /// auto-termination code: `autoTerminateSpans()` runs just before the part-will-end hook and
        /// would end the span as an error first.
        ///
        /// Opened as incomplete, so a span recovered after a kill or crash is flagged as such.
        private func openSpan(partId: EmbraceIdentifier, startTime: Date) {
            guard
                let span = try? otel?.createInternalSpan(
                    name: SpanSemantics.Smoothness.name,
                    type: .smoothness,
                    startTime: startTime,
                    attributes: [SpanSemantics.Smoothness.keyComplete: false]
                )
            else {
                return
            }

            // Seeded here since the change notification only fires on transitions.
            let initialThermalState = thermalState()
            let timer = makeCheckpointTimer()
            let previous = data.withLock { data -> OpenSpan? in
                let previous = data.openSpan
                data.openSpan = OpenSpan(
                    partId: partId,
                    span: span,
                    peakThermalState: initialThermalState,
                    checkpointTimer: timer
                )
                return previous
            }
            // The tracker closes a part before opening the next, so this only fires if a span leaked.
            previous?.checkpointTimer?.cancel()
            previous?.span.end()
        }

        private func makeCheckpointTimer() -> DispatchSourceTimer? {
            guard checkpointInterval > 0 else { return nil }

            let timer = DispatchSource.makeTimerSource(queue: checkpointQueue)
            timer.setEventHandler { [weak self] in
                self?.checkpoint()
            }
            timer.schedule(
                deadline: .now() + checkpointInterval,
                repeating: checkpointInterval,
                leeway: .milliseconds(Int(checkpointInterval * 100))
            )
            timer.activate()
            return timer
        }

        /// Called with the tracker's lock held, so it can't race the span's end.
        private func checkpointSpan(partId: EmbraceIdentifier, stats: SmoothnessSessionStats) {
            let currentThermalState = thermalState()
            let open = data.withLock { data -> OpenSpan? in
                guard data.openSpan?.partId == partId else { return nil }
                data.openSpan?.peakThermalState.raise(to: currentThermalState)
                return data.openSpan
            }
            guard let open else { return }

            setMetrics(on: open.span, stats: stats, peakThermalState: open.peakThermalState)
            open.span.setAttribute(key: SpanSemantics.Smoothness.keyCheckpointTime, value: stats.endTime.nanosecondsSince1970Truncated)
        }

        /// Called with the tracker's lock held, and usually the `SessionController` lock too. Keep it
        /// to one span end.
        private func endSpan(partId: EmbraceIdentifier, stats: SmoothnessSessionStats) {
            let currentThermalState = thermalState()
            let closed = data.withLock { data -> OpenSpan? in
                guard var open = data.openSpan, open.partId == partId else { return nil }
                data.openSpan = nil
                // Covers a change whose notification hasn't been delivered yet.
                open.peakThermalState.raise(to: currentThermalState)
                return open
            }
            guard let closed else { return }
            closed.checkpointTimer?.cancel()
            let span = closed.span

            // Always ended, including with zero frames: the span is already persisted and zero is valid.
            setMetrics(on: span, stats: stats, peakThermalState: closed.peakThermalState)
            span.setAttribute(key: SpanSemantics.Smoothness.keyComplete, value: true)
            if let endReason = closed.endReason {
                span.setAttribute(key: SpanSemantics.Smoothness.keyEndReason, value: endReason)
            }
            span.end(endTime: stats.endTime)
        }

        private func setMetrics(on span: EmbraceSpan, stats: SmoothnessSessionStats, peakThermalState: ProcessInfo.ThermalState) {
            span.setAttribute(key: SpanSemantics.Smoothness.keyFrameCount, value: stats.frameCount)
            span.setAttribute(key: SpanSemantics.Smoothness.keyNormalizedDroppedFrames, value: stats.normalizedDroppedFrames)
            span.setAttribute(key: SpanSemantics.Smoothness.keyHangCount, value: stats.cappedTickCount)
            span.setAttribute(key: SpanSemantics.Smoothness.keyPeakThermalState, value: peakThermalState.semanticValue)
        }
    }

    extension ProcessInfo.ThermalState {
        /// Raises `self` to `other` if `other` is more severe.
        fileprivate mutating func raise(to other: ProcessInfo.ThermalState) {
            if other.rawValue > rawValue {
                self = other
            }
        }

        fileprivate var semanticValue: String {
            switch self {
            case .nominal: return SpanSemantics.Smoothness.ThermalState.nominal
            case .fair: return SpanSemantics.Smoothness.ThermalState.fair
            case .serious: return SpanSemantics.Smoothness.ThermalState.serious
            case .critical: return SpanSemantics.Smoothness.ThermalState.critical
            @unknown default: return SpanSemantics.Smoothness.ThermalState.unknown
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
