//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceSemantics
    #endif

    /// Frame accounting for one closed foreground part.
    ///
    /// Uses Android's smoothness units: `normalizedDroppedFrames` is the total late time expressed in
    /// 60fps reference frames, so it is refresh-rate independent (one dropped frame is 0.5 at 120Hz, 2.0
    /// at 30Hz). Expected frames are not stored; like Android, they are implied by the part's duration
    /// (`duration * referenceFrameRate`).
    ///
    /// `frameCount` does not mean the same as Android's: see its doc comment.
    struct SmoothnessPartStats {

        /// The fixed frame rate all dropped-frame counts are normalized to.
        static let referenceFrameRate: Double = 60

        let endTime: Date

        /// Display link ticks (vsyncs) delivered while the part was open, not frames the app
        /// rendered.
        ///
        /// The display link fires at the display's refresh rate whether or not the app draws, so an idle
        /// screen still counts 60 or 120 per second. Android's `frameCount` only counts rendered frames,
        /// so ratios against it are not comparable across platforms.
        let frameCount: Int

        /// Total late time while the part was open, after the hang ceiling is applied, in 60fps
        /// reference frames.
        let normalizedDroppedFrames: Double

        /// Ticks later than the hang threshold.
        let hangCount: Int
    }

    /// Accumulates frame lateness for the current foreground part, capping each tick at `hangThreshold`.
    /// Opens on part start, or on did-become-active for the cold-start swap, and closes from
    /// `.embraceSessionPartWillEndSync`. Must be created on main; one lock guards all state, since the
    /// close can run off main.
    final class SmoothnessPartTracker {

        /// Called on the main thread when a foreground part opens.
        ///
        /// Invoked with the tracker's lock held, so a concurrent close waits until it returns. Must not
        /// call back into the tracker.
        var onPartOpened: ((_ partId: EmbraceIdentifier, _ startTime: Date) -> Void)?

        /// Called when a foreground part closes, on whichever thread closed it. When the close comes
        /// from `.embraceSessionPartWillEndSync`, the `SessionController` lock is also held.
        ///
        /// Invoked with the tracker's lock held. Must do minimal work, must not call back into the
        /// tracker, and must never `DispatchQueue.main.sync`.
        var onPartClosed: ((_ partId: EmbraceIdentifier, _ stats: SmoothnessPartStats) -> Void)?

        /// Frames counted so far in the part currently being accumulated, or `0` if none is open.
        var openFrameCount: Int { lock.locked { state.openPart?.frameCount ?? 0 } }

        /// Must be called on the main thread.
        ///
        /// - Parameters:
        ///   - hangThreshold: Per-tick ceiling, shared with `HangCaptureService`.
        ///   - currentSession: Returns the current session part. Called with the tracker's lock held, so
        ///     it must not take `SessionController`'s lock, which is held while the will-end hook takes
        ///     the tracker's lock. `SessionController.currentSession` only takes its own session mutex.
        ///   - notificationCenter: Where `.embraceSessionPartDidStart` and the app's did-become-active
        ///     notification are posted.
        ///   - embraceNotificationCenter: Where `.embraceSessionPartWillEndSync` is posted.
        init(
            hangThreshold: TimeInterval,
            currentSession: @escaping () -> EmbraceSession?,
            notificationCenter: NotificationCenter,
            embraceNotificationCenter: NotificationCenter
        ) {
            self.state = TrackerState(hangThreshold: hangThreshold)
            self.currentSession = currentSession
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter

            notificationCenter.addObserver(
                self,
                selector: #selector(sessionPartDidStart),
                name: .embraceSessionPartDidStart,
                object: nil
            )

            notificationCenter.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: SmoothnessPartTracker.didBecomeActiveNotification,
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

        /// Sets the maximum late time a single tick can contribute to the part's dropped frames.
        func setHangThreshold(_ hangThreshold: TimeInterval) {
            lock.locked { state.hangThreshold = hangThreshold }
        }

        // MARK: - Frame accounting

        /// Lateness below this fraction of the tick's frame interval counts as on time.
        static let noiseFloorFraction: Double = 0.5

        /// Feed this from `FrameTimingSource.onTick`. No-ops while no part is open.
        func record(_ tick: FrameTimingSource.Tick) {
            var late = Self.lateness(of: tick)

            lock.locked {
                guard state.openPart != nil else { return }

                if late > state.hangThreshold {
                    late = state.hangThreshold
                    state.openPart?.hangCount += 1
                }

                state.openPart?.frameCount += 1
                state.openPart?.droppedDuration += late
            }
        }

        /// The tick's lateness, never negative, after two corrections that keep time which isn't a
        /// dropped frame from adding up over long parts:
        /// - **Refresh rate step-down.** When the frame interval grows between ticks (ProMotion adaptive
        ///   refresh, Low Power Mode, thermal caps), the tick lands up to that growth after the previous
        ///   `targetTimestamp` even though no frame was missed. The growth is subtracted.
        /// - **Noise floor.** Ticks land on vsync boundaries, so a real miss is late by at least about one
        ///   frame interval. Lateness below `noiseFloorFraction` of the tick's frame interval is scheduling
        ///   jitter and counts as `0`. Lateness at or above it is passed through unchanged, not quantized
        ///   into whole missed vsyncs, so partial-frame drops aren't lost.
        static func lateness(of tick: FrameTimingSource.Tick) -> TimeInterval {
            let rateStepDown = max(0, tick.frameInterval - tick.previousFrameInterval)
            let late = tick.delay - rateStepDown

            return late < noiseFloorFraction * tick.frameInterval ? 0 : max(0, late)
        }

        // MARK: - Part lifecycle

        /// Opens the current part if it is foreground and not already open. Call on the main thread.
        func openCurrentForegroundPart() {
            guard let session = currentSession() else { return }

            open(partId: session.id)
        }

        /// Opens now rather than at the part's start time. Frames are only accumulated from here, so a
        /// backdated span would count the unmeasured gap as smooth. And the previous part ends at exactly
        /// the part's start time, so a span starting there would also be fetched into its payload.
        func open(partId: EmbraceIdentifier) {
            lock.locked {
                guard state.openPart == nil, !state.isInvalidated,
                    let current = currentSession(), current.id == partId, current.state == .foreground,
                    state.lastEndedPartId != partId
                else {
                    return
                }

                state.openPart = OpenPart(partId: partId)
                onPartOpened?(partId, Date())
            }
        }

        /// Closes whichever part is open and reports it, and stops the tracker from opening any part
        /// again.
        ///
        /// Called when the tracker is retired or the app terminates. Its observers stay registered until
        /// it is released, which can happen a main turn later, and a part start delivered in that window
        /// must not open a span nothing will end.
        ///
        /// - Returns: Whether a part was open and has now been reported.
        @discardableResult
        func invalidate(at endTime: Date) -> Bool {
            lock.locked {
                state.isInvalidated = true
                guard let partId = state.openPart?.partId else { return false }

                state.lastEndedPartId = partId
                closeLocked(at: endTime)
                return true
            }
        }

        // MARK: - Private

        private struct OpenPart {
            let partId: EmbraceIdentifier
            var frameCount = 0
            var droppedDuration: TimeInterval = 0
            var hangCount = 0
        }

        private struct TrackerState {
            var hangThreshold: TimeInterval
            var openPart: OpenPart?
            /// The last part that ended, which must not be opened again.
            var lastEndedPartId: EmbraceIdentifier?
            /// Set by `invalidate(at:)`. No part opens once it's set.
            var isInvalidated = false
        }

        /// Raw notification name to avoid a direct UIKit dependency.
        private static let didBecomeActiveNotification =
            Notification.Name("UIApplicationDidBecomeActiveNotification")

        private let currentSession: () -> EmbraceSession?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private let lock = UnfairLock()
        private var state: TrackerState

        /// Must be called with `lock` held.
        private func closeLocked(at endTime: Date) {
            guard let part = state.openPart else { return }

            state.openPart = nil
            onPartClosed?(part.partId, stats(for: part, endTime: endTime))
        }

        private func stats(for part: OpenPart, endTime: Date) -> SmoothnessPartStats {
            SmoothnessPartStats(
                endTime: endTime,
                frameCount: part.frameCount,
                normalizedDroppedFrames: part.droppedDuration * SmoothnessPartStats.referenceFrameRate,
                hangCount: part.hangCount
            )
        }

        /// `SessionController` posts this asynchronously on the main thread.
        @objc private func sessionPartDidStart(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession, session.state == .foreground else { return }

            open(partId: session.id)
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
        /// Marks the part as ended if it is open or current, so a late open for it is ignored. Any other
        /// id is stale and ignored, so it can't overwrite the record of the part that did end.
        ///
        /// Closes at the part's own end time, since the next part starts at exactly that time and a
        /// later end would put the span in the next part's payload too.
        @objc private func sessionPartWillEnd(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession else { return }

            let endTime = notification.userInfo?[SessionController.sessionPartWillEndSyncEndTimeKey] as? Date ?? Date()
            lock.locked {
                let isOpen = state.openPart?.partId == session.id
                guard isOpen || currentSession()?.id == session.id else { return }

                state.lastEndedPartId = session.id
                guard isOpen else { return }

                closeLocked(at: endTime)
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
