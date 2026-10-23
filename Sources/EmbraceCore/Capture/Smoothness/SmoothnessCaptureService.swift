//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

// Frame timing relies on `CADisplayLink`, which is unavailable on watchOS and can't be constructed
// standalone on macOS.
#if !os(watchOS) && !os(macOS)

    import Foundation

    #if DEBUG
        import os.signpost
    #endif

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCaptureService
        import EmbraceCommonInternal
        import EmbraceSemantics
        import EmbraceConfiguration
        import EmbraceObjCUtilsInternal
    #endif

    /// Service that measures rendering smoothness. It writes each foreground part's dropped and expected
    /// frames, hang count and peak thermal state onto the part's session span just before the part's
    /// payload is built, and serves running totals that `emb-screen-view` spans are measured against.
    ///
    /// A part that ends without the part-will-end hook (terminate, crash, watchdog, jetsam) carries no
    /// smoothness attributes.
    ///
    /// Installed by default but dormant (no `CADisplayLink`) until remote config enables it
    /// (`EmbraceConfigurable.isSmoothnessEnabled`). Enabled while running, it counts the current
    /// foreground part from that point. Disabled while running, it writes the frames counted so far.
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
                sessionSpan: { partId in
                    guard let controller = Embrace.client?.sessionController, controller.currentSession?.id == partId else {
                        return nil
                    }
                    return controller.currentSessionSpan
                },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter,
                ignoresRemoteConfig: ignoresRemoteConfig
            )
        }

        /// - Parameters:
        ///   - sessionSpan: Returns the session span of the given part, if it is still current. Called
        ///     with the tracker's lock held, and usually `SessionController`'s, so it must only take the
        ///     controller's session mutex.
        ///   - environment: Checked for `EMBAllowWatchdogInDebugger=1`, which keeps it enabled anyway.
        ///   - attachesDisplayLink: Whether the frame timing source runs a real `CADisplayLink`. Tests
        ///     pass `false` and drive frames through the accumulator.
        init(
            currentSession: @escaping () -> EmbraceSession?,
            sessionSpan: @escaping (EmbraceIdentifier) -> EmbraceSpan?,
            notificationCenter: NotificationCenter,
            embraceNotificationCenter: NotificationCenter,
            thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
            debuggerAttached: @escaping () -> Bool = { EMBDevice.isDebuggerAttached },
            environment: [String: String] = ProcessInfo.processInfo.environment,
            ignoresRemoteConfig: Bool = false,
            attachesDisplayLink: Bool = true
        ) {
            self.currentSession = currentSession
            self.sessionSpan = sessionSpan
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter
            self.thermalState = thermalState
            self.debuggerAttached = debuggerAttached
            self.environment = environment
            self.ignoresRemoteConfig = ignoresRemoteConfig
            self.attachesDisplayLink = attachesDisplayLink
            super.init()

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

            onMain { [weak self] in self?.activate() }
        }

        public override func onStop() {
            tearDown()
        }

        public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
            let hangThreshold = config.hangLimits.hangThreshold
            let isEnabled = config.isSmoothnessEnabled
            let (accumulator, wasEnabled) = data.withLock { data -> (FrameAccumulator?, Bool) in
                let wasEnabled = data.isRemotelyEnabled
                data.hangThreshold = hangThreshold
                data.isRemotelyEnabled = isEnabled
                return (data.capture?.accumulator, wasEnabled)
            }
            accumulator?.setHangThreshold(hangThreshold)

            // Before start, the value is only stored; `onStart()` applies it.
            guard !ignoresRemoteConfig, isEnabled != wasEnabled, state.load(order: .acquire) == .active else { return }

            if isEnabled {
                logger?.debug("[Smoothness] Enabled by remote config.")
                onMain { [weak self] in self?.activate() }
            } else {
                logger?.debug("[Smoothness] Disabled by remote config.")
                tearDown()
            }
        }

        /// Expected frames counted so far in the open foreground part, or `0` if none is open or the
        /// service isn't running. SPI for benchmarks, to prove the service is active.
        @_spi(Private)
        public var openPartFrameCount: Int {
            tracker?.openPartCounts?.expectedFrames ?? 0
        }

        // MARK: - Internal

        /// App-wide running totals, or `nil` while the service isn't running. Screens snapshot these on
        /// appear and report the difference when they end.
        var frameCountTotals: SmoothnessFrameCounts? {
            data.withLock { $0.capture?.accumulator }?.totals
        }

        var hangThreshold: TimeInterval {
            data.withLock { $0.hangThreshold }
        }

        /// `nil` while the service isn't running.
        var accumulator: FrameAccumulator? {
            data.withLock { $0.capture?.accumulator }
        }

        /// `nil` while the service isn't running.
        var tracker: SmoothnessPartTracker? {
            data.withLock { $0.capture?.tracker }
        }

        /// `nil` while the service isn't running.
        var frameTimingSource: FrameTimingSource? {
            data.withLock { $0.capture?.source }
        }

        /// In debug builds, `EMBSmoothnessSignposts=1` wraps each tick in an `os_signpost` interval
        /// (subsystem `io.embrace.sdk`, category `Smoothness`, name `Tick`) so its cost can be profiled
        /// in Instruments. The choice is made once here, so the per-tick path never branches on it.
        static func makeTickHandler(
            accumulator: FrameAccumulator,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> (FrameTimingSource.Tick) -> Void {
            let handler: (FrameTimingSource.Tick) -> Void = { [weak accumulator] tick in
                accumulator?.record(tick)
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

        private var isBlockedByDebugger: Bool {
            debuggerAttached() && environment["EMBAllowWatchdogInDebugger"] != "1"
        }

        /// Whether remote config lets the capture run. Call with `data`'s lock held.
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

        /// Must be called on the main thread. The recheck under the lock drops the new capture if a
        /// teardown raced in off main while it was being built.
        private func activate() {
            guard !isBlockedByDebugger,
                data.withLock({ $0.capture == nil && isRunnable($0) })
            else {
                return
            }

            let accumulator = FrameAccumulator(hangThreshold: hangThreshold)
            let tracker = SmoothnessPartTracker(
                accumulator: accumulator,
                currentSession: currentSession,
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter
            )
            tracker.onPartOpened = { [weak self] partId in
                self?.partOpened(partId: partId)
            }
            tracker.onPartClosed = { [weak self] partId, counts in
                self?.partClosed(partId: partId, counts: counts)
            }

            let source = FrameTimingSource(notificationCenter: notificationCenter, attachesDisplayLink: attachesDisplayLink)
            source.onTick = Self.makeTickHandler(accumulator: accumulator)

            let stored = data.withLock { data -> Bool in
                guard state.load(order: .acquire) == .active, data.capture == nil, isRunnable(data) else { return false }
                data.capture = ActiveCapture(source: source, accumulator: accumulator, tracker: tracker)
                return true
            }

            // The current foreground part may have started before the tracker existed.
            if stored {
                tracker.open()
            }
        }

        /// Closes the open part and releases the capture on main, where its `CADisplayLink` must be
        /// invalidated.
        private func tearDown() {
            let capture = data.withLock { data -> ActiveCapture? in
                let previous = data.capture
                data.capture = nil
                return previous
            }
            guard let capture else { return }

            capture.tracker.invalidate()

            if !Thread.isMainThread {
                DispatchQueue.main.async { withExtendedLifetime(capture) {} }
            }
        }

        private struct ActiveCapture {
            let source: FrameTimingSource
            let accumulator: FrameAccumulator
            let tracker: SmoothnessPartTracker
        }

        private struct OpenPart {
            let partId: EmbraceIdentifier
            var peakThermalState: ProcessInfo.ThermalState
        }

        private struct MutableData {
            var hangThreshold: TimeInterval = HangLimits.defaultHangThreshold
            var isRemotelyEnabled = false
            var capture: ActiveCapture?
            var openPart: OpenPart?
        }

        private let currentSession: () -> EmbraceSession?
        private let sessionSpan: (EmbraceIdentifier) -> EmbraceSpan?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private let thermalState: () -> ProcessInfo.ThermalState
        private let debuggerAttached: () -> Bool
        private let environment: [String: String]
        private let ignoresRemoteConfig: Bool
        private let attachesDisplayLink: Bool

        /// Lock order: the tracker's lock, then this one. Never call into the tracker while holding it.
        private let data = EmbraceMutex(MutableData())

        /// Posted on an arbitrary thread. Only raises the open part's peak; never touches the tracker.
        @objc private func thermalStateDidChange() {
            let state = thermalState()
            data.withLock { data in
                data.openPart?.peakThermalState.raise(to: state)
            }
        }

        /// Called on main with the tracker's lock held.
        private func partOpened(partId: EmbraceIdentifier) {
            // Seeded here since the change notification only fires on transitions.
            let initialThermalState = thermalState()
            data.withLock { data in
                data.openPart = OpenPart(partId: partId, peakThermalState: initialThermalState)
            }
        }

        /// Called with the tracker's lock held, and usually the `SessionController` lock too. Keep it
        /// minimal.
        ///
        /// Written as internal attributes, like the session span's other SDK attributes, so they don't
        /// count against its attribute limit. Always written, including zeros: the part was measured.
        private func partClosed(partId: EmbraceIdentifier, counts: SmoothnessFrameCounts) {
            let currentThermalState = thermalState()
            let closed = data.withLock { data -> OpenPart? in
                guard var open = data.openPart, open.partId == partId else { return nil }
                data.openPart = nil
                // Covers a change whose notification hasn't been delivered yet.
                open.peakThermalState.raise(to: currentThermalState)
                return open
            }
            guard let closed, let span = sessionSpan(partId) else { return }

            span.setInternalAttribute(key: SpanSemantics.Smoothness.keyDroppedFrames, value: counts.droppedFrames)
            span.setInternalAttribute(key: SpanSemantics.Smoothness.keyExpectedFrames, value: counts.expectedFrames)
            span.setInternalAttribute(key: SpanSemantics.Smoothness.keyHangCount, value: counts.hangCount)
            span.setInternalAttribute(key: SpanSemantics.Smoothness.keyPeakThermalState, value: closed.peakThermalState.semanticValue)
        }
    }

    extension ProcessInfo.ThermalState {
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
