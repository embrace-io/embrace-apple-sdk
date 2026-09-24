//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    /// Frame accounting for one completed foreground session.
    ///
    /// Matches Android's smoothness units: `frameCount` is the real (unnormalized) number of frames
    /// rendered, and `normalizedDroppedFrames` is the total late time expressed in 60fps reference
    /// frames, so it is refresh-rate independent (one dropped frame is 0.5 at 120Hz, 2.0 at 30Hz).
    /// Expected frames are not stored; like Android, they are implied by the session's duration
    /// (`duration * referenceFrameRate`).
    struct SmoothnessSessionStats: Equatable {

        /// The fixed frame rate all dropped-frame counts are normalized to.
        static let referenceFrameRate: Double = 60

        let startTime: Date
        let endTime: Date

        /// Frames rendered (display link ticks delivered) while the session was open.
        let frameCount: Int

        /// Total late time while the session was open, after the hang ceiling is applied, in 60fps
        /// reference frames.
        let normalizedDroppedFrames: Double

        /// Ticks whose lateness exceeded the hang ceiling and were capped.
        let cappedTickCount: Int
    }

    /// Owns the frame-drop accumulator for the app's current foreground session.
    ///
    /// Opens when `SessionController` posts `.embraceSessionPartDidStart` for a foreground part,
    /// attaching itself as `FrameDropClassifier.currentAccumulator`. Closes when
    /// `.embraceForegroundSessionDidEnd` fires, detaching from the classifier and reporting the
    /// session's totals through `onSessionEnded`.
    ///
    /// A single tick that is later than `hangThreshold` (a main-thread hang) is capped to
    /// `hangThreshold`, so one stall can't dominate an otherwise long session. The session stays open
    /// across a hang.
    ///
    /// Late time is summed as a continuous duration and only normalized to 60fps reference frames
    /// when the session closes, so no per-tick rounding accumulates over long sessions.
    ///
    /// All state is confined to the main thread.
    final class SmoothnessSessionTracker: FrameDropAccumulator {

        /// Called on the main thread when a foreground session closes. Callers should hop off main
        /// before doing any non-trivial work.
        var onSessionEnded: ((SmoothnessSessionStats) -> Void)?

        /// Maximum late time a single tick can contribute to the session's dropped frames.
        let hangThreshold: TimeInterval

        /// Whether a foreground session is currently being accumulated.
        var isSessionOpen: Bool { openSession != nil }

        /// Must be called on the main thread.
        ///
        /// - Parameters:
        ///   - classifier: The classifier this tracker attaches to while a session is open.
        ///   - hangThreshold: Per-tick ceiling, shared with `HangCaptureService`.
        ///   - notificationCenter: Where `.embraceSessionPartDidStart` is posted.
        ///   - embraceNotificationCenter: Where `.embraceForegroundSessionDidEnd` is posted.
        init(
            classifier: FrameDropClassifier,
            hangThreshold: TimeInterval = FrameRateMonitor.defaultAppleHangThreshold,
            notificationCenter: NotificationCenter = .default,
            embraceNotificationCenter: NotificationCenter = Embrace.notificationCenter
        ) {
            self.classifier = classifier
            self.hangThreshold = hangThreshold
            self.notificationCenter = notificationCenter
            self.embraceNotificationCenter = embraceNotificationCenter

            notificationCenter.addObserver(
                self,
                selector: #selector(sessionPartDidStart),
                name: .embraceSessionPartDidStart,
                object: nil
            )

            embraceNotificationCenter.addObserver(
                self,
                selector: #selector(foregroundSessionDidEnd),
                name: .embraceForegroundSessionDidEnd,
                object: nil
            )
        }

        deinit {
            notificationCenter.removeObserver(self)
            embraceNotificationCenter.removeObserver(self)
        }

        // MARK: - FrameDropAccumulator

        func recordFrame(lateBy: TimeInterval) {
            guard openSession != nil else { return }

            var late = lateBy
            if late > hangThreshold {
                late = hangThreshold
                openSession?.cappedTickCount += 1
            }

            openSession?.frameCount += 1
            openSession?.droppedDuration += late
        }

        // MARK: - Session lifecycle

        /// Opens a new accumulator, closing any session that was left open.
        func open(at startTime: Date) {
            if openSession != nil {
                close(at: startTime)
            }

            openSession = OpenSession(startTime: startTime)
            classifier.currentAccumulator = self
        }

        /// Closes the current accumulator and reports it. No-ops if no session is open.
        func close(at endTime: Date) {
            guard let session = openSession else { return }

            openSession = nil
            if classifier.currentAccumulator === self {
                classifier.currentAccumulator = nil
            }

            onSessionEnded?(
                SmoothnessSessionStats(
                    startTime: session.startTime,
                    endTime: endTime,
                    frameCount: session.frameCount,
                    normalizedDroppedFrames: session.droppedDuration * SmoothnessSessionStats.referenceFrameRate,
                    cappedTickCount: session.cappedTickCount
                )
            )
        }

        // MARK: - Private

        private struct OpenSession {
            let startTime: Date
            var frameCount = 0
            var droppedDuration: TimeInterval = 0
            var cappedTickCount = 0
        }

        private let classifier: FrameDropClassifier
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private var openSession: OpenSession?

        /// `SessionController` posts this on the main thread.
        @objc private func sessionPartDidStart(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession,
                session.state == .foreground
            else {
                return
            }

            let startTime = session.startTime
            onMain { $0.open(at: startTime) }
        }

        /// `SessionController` posts this on whichever thread ends the session, with the end `Date`
        /// as the object.
        @objc private func foregroundSessionDidEnd(_ notification: Notification) {
            let endTime = notification.object as? Date ?? Date()
            onMain { $0.close(at: endTime) }
        }

        private func onMain(_ block: @escaping (SmoothnessSessionTracker) -> Void) {
            if Thread.isMainThread {
                block(self)
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    block(self)
                }
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
