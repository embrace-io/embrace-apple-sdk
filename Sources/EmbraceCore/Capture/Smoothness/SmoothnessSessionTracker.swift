//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceSemantics
    #endif

    /// Frame accounting for one completed foreground session.
    ///
    /// Uses Android's smoothness units: `normalizedDroppedFrames` is the total late time expressed in
    /// 60fps reference frames, so it is refresh-rate independent (one dropped frame is 0.5 at 120Hz, 2.0
    /// at 30Hz). Expected frames are not stored; like Android, they are implied by the session's duration
    /// (`duration * referenceFrameRate`).
    ///
    /// `frameCount` does not mean the same as Android's: see its doc comment.
    struct SmoothnessSessionStats: Equatable {

        /// The fixed frame rate all dropped-frame counts are normalized to.
        static let referenceFrameRate: Double = 60

        let startTime: Date
        let endTime: Date

        /// Display link ticks (vsyncs) delivered while the session was open, not frames the app
        /// rendered.
        ///
        /// The display link fires at the display's refresh rate whether or not the app draws, so an idle
        /// screen still counts 60 or 120 per second. Android's `frameCount` only counts rendered frames,
        /// so ratios against it are not comparable across platforms.
        let frameCount: Int

        /// Total late time while the session was open, after the hang ceiling is applied, in 60fps
        /// reference frames.
        let normalizedDroppedFrames: Double

        /// Ticks whose lateness exceeded the hang ceiling and were capped, reported as the span's hang
        /// count.
        ///
        /// Uses the same `> hangThreshold` test and threshold as `FrameRateMonitor`, so it is how a
        /// `smoothness` span is correlated with `HangCaptureService`'s hang spans. The test is applied to
        /// the lateness after `FrameDropClassifier`'s corrections, which only differs from the raw delay
        /// by at most one frame interval, and only on a refresh rate step-down. It can still differ
        /// from the number of hang spans in the part: it isn't limited by `HangLimits.hangPerSession`,
        /// it's counted even when `HangCaptureService` isn't installed, and each service reads its own
        /// `CADisplayLink`, so a stall right at the threshold can land on one side only.
        let cappedTickCount: Int
    }

    /// Owns the frame-drop accumulator for the app's current foreground session part.
    ///
    /// Opens for a foreground part when either:
    /// - `SessionController` posts `.embraceSessionPartDidStart` for it, or
    /// - the app becomes active while the current part is already foreground. This covers the
    ///   cold-start swap, where `iOSSessionLifecycle` flips a background cold-start part to foreground
    ///   in place and no `.embraceSessionPartDidStart` is posted.
    ///
    /// Both paths are keyed by part id, so they dedupe. A part is only opened while it is still the
    /// current part and has not already ended, because `.embraceSessionPartDidStart` is delivered
    /// asynchronously on main and can arrive after its part ended.
    ///
    /// Closes synchronously from `.embraceSessionPartWillEndSync`, which `SessionController` posts
    /// before the ending part's payload is queued, on whichever thread is ending the part. The session
    /// is closed at the part's end time from the notification, so its span belongs to that part only.
    ///
    /// A single tick that is later than `hangThreshold` (a main-thread hang) is capped to
    /// `hangThreshold`, so one stall can't dominate an otherwise long session, and is counted in
    /// `cappedTickCount`. The session stays open across a hang.
    ///
    /// Late time is summed as a continuous duration and only normalized to 60fps reference frames
    /// when the session closes, so no per-tick rounding accumulates over long sessions.
    ///
    /// Must be created on the main thread. All state is guarded by a single unfair lock, since the
    /// close can run off main.
    final class SmoothnessSessionTracker: FrameDropAccumulator {

        /// Called on the main thread when a foreground part opens.
        ///
        /// Invoked with the tracker's lock held, so a concurrent close waits until it returns. Must not
        /// call back into the tracker.
        var onSessionOpened: ((_ partId: EmbraceIdentifier, _ startTime: Date) -> Void)?

        /// Called when a foreground part closes, on whichever thread closed it. When the close comes
        /// from `.embraceSessionPartWillEndSync`, the `SessionController` lock is also held.
        ///
        /// Invoked with the tracker's lock held. Must do minimal work, must not call back into the
        /// tracker, and must never `DispatchQueue.main.sync`.
        var onSessionClosed: ((_ partId: EmbraceIdentifier, _ stats: SmoothnessSessionStats) -> Void)?

        /// Called from `checkpoint(at:)` with the open part's stats so far, whose `endTime` is the
        /// checkpoint time. The part stays open.
        ///
        /// Invoked with the tracker's lock held, so checkpoints and the close are reported in order and a
        /// checkpoint can never land after the close. Same rules as `onSessionClosed`.
        var onSessionCheckpoint: ((_ partId: EmbraceIdentifier, _ stats: SmoothnessSessionStats) -> Void)?

        /// Maximum late time a single tick can contribute to the session's dropped frames.
        var hangThreshold: TimeInterval {
            get { lock.locked { state.hangThreshold } }
            set { lock.locked { state.hangThreshold = newValue } }
        }

        /// Whether a foreground session is currently being accumulated.
        var isSessionOpen: Bool { lock.locked { state.openSession != nil } }

        /// The id of the part currently being accumulated, if any.
        var openPartId: EmbraceIdentifier? { lock.locked { state.openSession?.partId } }

        /// Frames counted so far in the part currently being accumulated, or `0` if none is open.
        var openFrameCount: Int { lock.locked { state.openSession?.frameCount ?? 0 } }

        /// Must be called on the main thread.
        ///
        /// - Parameters:
        ///   - classifier: The classifier this tracker attaches to for its whole lifetime.
        ///   - hangThreshold: Per-tick ceiling, shared with `HangCaptureService`.
        ///   - currentSession: Returns the current session part. Called with the tracker's lock held, so
        ///     it must not take `SessionController`'s lock, which is held while the will-end hook takes
        ///     the tracker's lock. `SessionController.currentSession` only takes its own session mutex.
        ///   - notificationCenter: Where `.embraceSessionPartDidStart` and the app's did-become-active
        ///     notification are posted.
        ///   - embraceNotificationCenter: Where `.embraceSessionPartWillEndSync` is posted.
        init(
            classifier: FrameDropClassifier,
            hangThreshold: TimeInterval = FrameRateMonitor.defaultAppleHangThreshold,
            currentSession: @escaping () -> EmbraceSession? = { Embrace.client?.sessionController.currentSession },
            notificationCenter: NotificationCenter = .default,
            embraceNotificationCenter: NotificationCenter = Embrace.notificationCenter
        ) {
            self.classifier = classifier
            self.state = State(hangThreshold: hangThreshold)
            self.currentSession = currentSession
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter

            // Stay attached for the tracker's lifetime; `recordFrame` no-ops while no session is open.
            // Detaching on close would mutate the main-only classifier from the closing thread.
            classifier.currentAccumulator = self

            notificationCenter.addObserver(
                self,
                selector: #selector(sessionPartDidStart),
                name: .embraceSessionPartDidStart,
                object: nil
            )

            notificationCenter.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: SmoothnessSessionTracker.didBecomeActiveNotification,
                object: nil
            )

            embraceNotificationCenter.addObserver(
                self,
                selector: #selector(sessionPartWillEnd),
                name: .embraceSessionPartWillEndSync,
                object: nil
            )
        }

        deinit {
            notificationCenter.removeObserver(self)
            embraceNotificationCenter.removeObserver(self)
        }

        // MARK: - FrameDropAccumulator

        func recordFrame(lateBy: TimeInterval) {
            lock.locked {
                guard state.openSession != nil else { return }

                var late = lateBy
                if late > state.hangThreshold {
                    late = state.hangThreshold
                    state.openSession?.cappedTickCount += 1
                }

                state.openSession?.frameCount += 1
                state.openSession?.droppedDuration += late
            }
        }

        // MARK: - Session lifecycle

        /// Opens the current part if it is foreground and not already open. Call on the main thread.
        func openCurrentForegroundPart(at startTime: Date = Date()) {
            // Early exit only; `open` repeats the check under the lock.
            guard let session = currentSession(), session.state == .foreground else { return }

            open(partId: session.id, at: startTime)
        }

        /// Opens an accumulator for `partId`, closing any other part that was left open.
        ///
        /// No-ops if `partId` is already open, has already ended or been skipped, or isn't the current
        /// foreground part, or if the tracker has been invalidated.
        ///
        /// The current part is checked under the lock, so a part that ends between a caller's own check
        /// and this call can't be reopened. `currentSession` still returns the ending part during the
        /// will-end hook, so `lastEndedPartId` covers that window.
        func open(partId: EmbraceIdentifier, at startTime: Date) {
            lock.locked {
                if state.openSession?.partId == partId { return }

                guard !state.isInvalidated,
                    let current = currentSession(), current.id == partId, current.state == .foreground,
                    state.lastEndedPartId != partId
                else {
                    return
                }

                closeLocked(at: startTime)

                state.openSession = OpenSession(partId: partId, startTime: startTime)
                onSessionOpened?(partId, startTime)
            }
        }

        /// Closes the accumulator for `partId` and reports it. No-ops if `partId` isn't open.
        ///
        /// Marks `partId` as ended if it is open or current, so a late open for it is ignored. Any other
        /// id is stale and ignored, so it can't overwrite the record of the part that did end.
        func close(partId: EmbraceIdentifier, at endTime: Date) {
            lock.locked {
                let isOpen = state.openSession?.partId == partId
                guard isOpen || currentSession()?.id == partId else { return }

                state.lastEndedPartId = partId
                guard isOpen else { return }

                closeLocked(at: endTime)
            }
        }

        /// Closes whichever part is open and reports it. No-ops if none is.
        ///
        /// Marks the closed part as ended, so a later open or will-end for it is ignored.
        ///
        /// - Returns: Whether a part was open and has now been reported.
        @discardableResult
        func closeOpenSession(at endTime: Date) -> Bool {
            lock.locked {
                guard let partId = state.openSession?.partId else { return false }

                state.lastEndedPartId = partId
                closeLocked(at: endTime)
                return true
            }
        }

        /// Closes whichever part is open, like `closeOpenSession(at:)`, and stops the tracker from
        /// opening any part again.
        ///
        /// Called when the tracker is retired. Its observers stay registered until it is released,
        /// which can happen a main turn later, and a part start delivered in that window must not open
        /// a span nothing will end.
        ///
        /// - Returns: Whether a part was open and has now been reported.
        @discardableResult
        func invalidate(at endTime: Date) -> Bool {
            lock.locked {
                state.isInvalidated = true
                guard let partId = state.openSession?.partId else { return false }

                state.lastEndedPartId = partId
                closeLocked(at: endTime)
                return true
            }
        }

        /// Stops the current part from being opened, if it's foreground.
        ///
        /// Called when the tracker is created partway through a foreground part, so the part's first span
        /// is the next part's rather than a partial one. A background part isn't skipped, so the cold-start
        /// swap to foreground still opens it.
        func skipCurrentForegroundPart() {
            lock.locked {
                guard let current = currentSession(), current.state == .foreground else { return }

                state.lastEndedPartId = current.id
            }
        }

        /// Reports the open part's stats so far without closing it. No-ops if no part is open.
        ///
        /// - Returns: Whether a part was open and has been reported.
        @discardableResult
        func checkpoint(at time: Date) -> Bool {
            lock.locked {
                guard let session = state.openSession else { return false }

                onSessionCheckpoint?(session.partId, stats(for: session, endTime: time))
                return true
            }
        }

        // MARK: - Private

        private struct OpenSession {
            let partId: EmbraceIdentifier
            let startTime: Date
            var frameCount = 0
            var droppedDuration: TimeInterval = 0
            var cappedTickCount = 0
        }

        private struct State {
            var hangThreshold: TimeInterval
            var openSession: OpenSession?
            /// The part that must not be opened: the last one closed, or one skipped because the tracker
            /// started partway through it.
            var lastEndedPartId: EmbraceIdentifier?
            /// Set by `invalidate(at:)`. No part opens once it's set.
            var isInvalidated = false
        }

        /// Raw notification name to avoid a direct UIKit dependency.
        private static let didBecomeActiveNotification =
            Notification.Name("UIApplicationDidBecomeActiveNotification")

        private let classifier: FrameDropClassifier
        private let currentSession: () -> EmbraceSession?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private let lock = UnfairLock()
        private var state: State

        /// Must be called with `lock` held.
        private func closeLocked(at endTime: Date) {
            guard let session = state.openSession else { return }

            state.openSession = nil
            onSessionClosed?(session.partId, stats(for: session, endTime: endTime))
        }

        private func stats(for session: OpenSession, endTime: Date) -> SmoothnessSessionStats {
            SmoothnessSessionStats(
                startTime: session.startTime,
                endTime: endTime,
                frameCount: session.frameCount,
                normalizedDroppedFrames: session.droppedDuration * SmoothnessSessionStats.referenceFrameRate,
                cappedTickCount: session.cappedTickCount
            )
        }

        /// `SessionController` posts this asynchronously on the main thread.
        ///
        /// The checks here are early exits only; `open` repeats them under the lock.
        @objc private func sessionPartDidStart(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession,
                session.state == .foreground,
                currentSession()?.id == session.id
            else {
                return
            }

            open(partId: session.id, at: session.startTime)
        }

        /// Catches the cold-start swap to foreground, which posts no `.embraceSessionPartDidStart`.
        ///
        /// Hops to the next main turn because observer order relative to `iOSSessionLifecycle`, which
        /// performs the swap from the same notification, isn't guaranteed.
        @objc private func appDidBecomeActive(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                self?.openCurrentForegroundPart()
            }
        }

        /// `SessionController` posts this synchronously with its lock held, on whichever thread is
        /// ending the part. Matching on the open part id is enough to filter out background parts.
        ///
        /// Closes at the part's own end time, since the next part starts at exactly that time and a
        /// later end would put the span in the next part's payload too.
        @objc private func sessionPartWillEnd(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession else { return }

            let endTime = notification.userInfo?[SessionController.sessionPartWillEndSyncEndTimeKey] as? Date ?? Date()
            close(partId: session.id, at: endTime)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
