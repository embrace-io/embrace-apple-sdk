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
    /// dropped frames normalized to 60fps, and the most severe thermal state seen while it was open.
    ///
    /// When the app is terminated while a foreground part is open (e.g. swiped away from the app
    /// switcher), the part is never ended, so the span is ended on `willTerminate` instead and flushed
    /// to storage before the notification returns. A part that never ends cleanly otherwise (crash,
    /// kill while suspended) surfaces as a failed span.
    ///
    /// - Note: Experimental and opt-in. Not part of the default capture services.
    public final class SmoothnessCaptureService: CaptureService {

        public convenience override init() {
            self.init(
                currentSession: { Embrace.client?.sessionController.currentSession },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter,
                flushStorage: { Embrace.client?.storage.coreData.save(allowMainQueue: true) }
            )
        }

        /// - Parameters:
        ///   - flushStorage: Blocks until pending storage writes, including the span's end, are on disk.
        ///   - thermalState: Reads the device's current thermal state.
        init(
            currentSession: @escaping () -> EmbraceSession?,
            notificationCenter: NotificationCenter,
            embraceNotificationCenter: NotificationCenter,
            flushStorage: @escaping () -> Void,
            thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }
        ) {
            self.currentSession = currentSession
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter
            self.flushStorage = flushStorage
            self.thermalState = thermalState
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
            if isDebuggerAttached() && ProcessInfo.processInfo.environment["EMBAllowWatchdogInDebugger"] != "1" {
                logger?.warning(
                    "[Smoothness] Disabled because a debugger is attached. Set the env var EMBAllowWatchdogInDebugger=1 to enable in debug mode.")
                return
            }

            if Thread.isMainThread {
                activate()
            } else {
                DispatchQueue.main.async { [weak self] in self?.activate() }
            }
        }

        public override func onStop() {
            // Release the pipeline so no CADisplayLink outlives an SDK stop. A part still open here
            // is closed with the frames counted so far, which ends its span normally.
            let pipeline = data.withLock { data -> Pipeline? in
                let previous = data.pipeline
                data.pipeline = nil
                return previous
            }
            pipeline?.tracker.closeOpenSession(at: Date())
        }

        public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
            let hangThreshold = config.hangLimits.hangThreshold
            let tracker = data.withLock { data -> SmoothnessSessionTracker? in
                data.hangThreshold = hangThreshold
                return data.pipeline?.tracker
            }
            // Set outside `data`'s lock: the tracker calls back into it with its own lock held.
            tracker?.hangThreshold = hangThreshold
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

        /// Builds the closure `FrameTimingSource` calls on every tick.
        ///
        /// In debug builds, `EMBSmoothnessSignposts=1` wraps each tick in an `os_signpost` interval
        /// (subsystem `io.embrace.sdk`, category `Smoothness`, name `Tick`) so its cost can be profiled
        /// in Instruments. The choice is made once here, so the per-tick path never branches on it.
        static func makeTickHandler(
            classifier: FrameDropClassifier,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> (TimeInterval) -> Void {
            let handler: (TimeInterval) -> Void = { [weak classifier] delay in
                classifier?.handle(delay: delay)
            }

            #if DEBUG
                if environment["EMBSmoothnessSignposts"] == "1" {
                    let log = OSLog(subsystem: "io.embrace.sdk", category: "Smoothness")
                    return { delay in
                        os_signpost(.begin, log: log, name: "Tick")
                        handler(delay)
                        os_signpost(.end, log: log, name: "Tick")
                    }
                }
            #endif

            return handler
        }

        // MARK: - Private

        /// Builds the timing source → classifier → tracker pipeline and swaps it in, but only if the
        /// service is still active. If a concurrent `onStop()` raced in, the new pipeline is dropped,
        /// which releases its CADisplayLink. Must be called on the main thread.
        private func activate() {
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

            let source = FrameTimingSource()
            source.onTick = Self.makeTickHandler(classifier: classifier)

            let stored = data.withLock { data -> Bool in
                guard state.load(order: .acquire) == .active else { return false }
                data.pipeline = Pipeline(source: source, classifier: classifier, tracker: tracker)
                return true
            }

            // The first foreground part may have started before the tracker existed.
            if stored {
                tracker.openCurrentForegroundPart()
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
        }

        private struct MutableData {
            var hangThreshold: TimeInterval = HangLimits().hangThreshold
            var pipeline: Pipeline?
            var openSpan: OpenSpan?
        }

        private let currentSession: () -> EmbraceSession?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private let flushStorage: () -> Void
        private let thermalState: () -> ProcessInfo.ThermalState

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
        private func openSpan(partId: EmbraceIdentifier, startTime: Date) {
            guard
                let span = try? otel?.createInternalSpan(
                    name: SpanSemantics.Smoothness.name,
                    type: .smoothness,
                    startTime: startTime
                )
            else {
                return
            }

            // Seeded here since the change notification only fires on transitions.
            let initialThermalState = thermalState()
            let previous = data.withLock { data -> EmbraceSpan? in
                let previous = data.openSpan?.span
                data.openSpan = OpenSpan(partId: partId, span: span, peakThermalState: initialThermalState)
                return previous
            }
            // The tracker closes a part before opening the next, so this only fires if a span leaked.
            previous?.end()
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
            let span = closed.span

            // Always ended, including with zero frames: the span is already persisted and zero is valid.
            span.setAttribute(key: SpanSemantics.Smoothness.keyFrameCount, value: stats.frameCount)
            span.setAttribute(key: SpanSemantics.Smoothness.keyNormalizedDroppedFrames, value: stats.normalizedDroppedFrames)
            span.setAttribute(key: SpanSemantics.Smoothness.keyPeakThermalState, value: closed.peakThermalState.semanticValue)
            span.end(endTime: stats.endTime)
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
