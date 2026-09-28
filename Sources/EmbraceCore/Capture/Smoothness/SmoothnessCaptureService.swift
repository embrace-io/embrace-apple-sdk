//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

// Frame timing relies on `CADisplayLink`, which is unavailable on watchOS and can't be constructed
// standalone on macOS.
#if !os(watchOS) && !os(macOS)

    /// Service that measures rendering smoothness and emits one `smoothness` span per foreground session
    /// part.
    ///
    /// The span opens when the foreground part starts, so it is persisted with that part's id right
    /// away, and ends just before the part's payload is built, carrying the part's frame count and
    /// dropped frames normalized to 60fps. A part that never ends cleanly (crash, kill) surfaces as a
    /// failed span.
    ///
    /// - Note: Experimental and opt-in. Not part of the default capture services.
    public final class SmoothnessCaptureService: CaptureService {

        public convenience override init() {
            self.init(
                currentSession: { Embrace.client?.sessionController.currentSession },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter
            )
        }

        init(
            currentSession: @escaping () -> EmbraceSession?,
            notificationCenter: NotificationCenter,
            embraceNotificationCenter: NotificationCenter
        ) {
            self.currentSession = currentSession
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter
            super.init()
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
            source.onTick = { [weak classifier] delay in
                classifier?.handle(delay: delay)
            }

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
        }

        private struct MutableData {
            var hangThreshold: TimeInterval = HangLimits().hangThreshold
            var pipeline: Pipeline?
            var openSpan: OpenSpan?
        }

        private let currentSession: () -> EmbraceSession?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter

        /// Lock order: the tracker's lock, then this one. Never call into the tracker while holding it.
        private let data = EmbraceMutex(MutableData())

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

            let previous = data.withLock { data -> EmbraceSpan? in
                let previous = data.openSpan?.span
                data.openSpan = OpenSpan(partId: partId, span: span)
                return previous
            }
            // The tracker closes a part before opening the next, so this only fires if a span leaked.
            previous?.end()
        }

        /// Called with the tracker's lock held, and usually the `SessionController` lock too. Keep it
        /// to one span end.
        private func endSpan(partId: EmbraceIdentifier, stats: SmoothnessSessionStats) {
            let span = data.withLock { data -> EmbraceSpan? in
                guard let open = data.openSpan, open.partId == partId else { return nil }
                data.openSpan = nil
                return open.span
            }
            guard let span else { return }

            // Always ended, including with zero frames: the span is already persisted and zero is valid.
            span.setAttribute(key: SpanSemantics.Smoothness.keyFrameCount, value: stats.frameCount)
            span.setAttribute(key: SpanSemantics.Smoothness.keyNormalizedDroppedFrames, value: stats.normalizedDroppedFrames)
            span.end(endTime: stats.endTime)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
