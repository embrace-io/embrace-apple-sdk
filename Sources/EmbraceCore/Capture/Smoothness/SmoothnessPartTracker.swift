//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceSemantics
    #endif

    /// Tracks the current foreground part and reports the frames the accumulator counted while it was
    /// open. Opens on part start, or on did-become-active for the cold-start swap, and closes from
    /// `.embraceSessionPartWillEndSync`. Must be created on main; one lock guards all state, since the
    /// close can run off main.
    final class SmoothnessPartTracker {

        /// Called on the main thread when a foreground part opens.
        ///
        /// Invoked with the tracker's lock held, so a concurrent close waits until it returns. Must not
        /// call back into the tracker.
        var onPartOpened: ((_ partId: EmbraceIdentifier) -> Void)?

        /// Called when a foreground part closes, on whichever thread closed it. When the close comes
        /// from `.embraceSessionPartWillEndSync`, the `SessionController` lock is also held.
        ///
        /// Invoked with the tracker's lock held. Must do minimal work, must not call back into the
        /// tracker, and must never `DispatchQueue.main.sync`.
        var onPartClosed: ((_ partId: EmbraceIdentifier, _ counts: SmoothnessFrameCounts) -> Void)?

        /// Frames counted so far in the part currently open, or `nil` if none is.
        var openPartCounts: SmoothnessFrameCounts? {
            lock.locked {
                guard let start = state.openPart?.start else { return nil }
                return accumulator.totals - start
            }
        }

        /// Must be called on the main thread.
        ///
        /// - Parameters:
        ///   - accumulator: The running totals each part is measured against.
        ///   - currentSession: Returns the current session part. Called with the tracker's lock held, so
        ///     it must not take `SessionController`'s lock, which is held while the will-end hook takes
        ///     the tracker's lock. `SessionController.currentSession` only takes its own session mutex.
        ///   - notificationCenter: Where `.embraceSessionPartDidStart` and the app's did-become-active
        ///     notification are posted.
        ///   - embraceNotificationCenter: Where `.embraceSessionPartWillEndSync` is posted.
        init(
            accumulator: FrameAccumulator,
            currentSession: @escaping () -> EmbraceSession?,
            notificationCenter: NotificationCenter,
            embraceNotificationCenter: NotificationCenter
        ) {
            self.accumulator = accumulator
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

        // MARK: - Part lifecycle

        /// Opens the current foreground part, if it is `partId` (or any part when `nil`). Call on the main
        /// thread.
        ///
        /// Counts from now rather than from the part's start, so frames before the tracker existed aren't
        /// attributed to the part.
        func open(partId: EmbraceIdentifier? = nil) {
            lock.locked {
                guard state.openPart == nil, !state.isInvalidated,
                    let current = currentSession(), current.id == partId ?? current.id, current.state == .foreground,
                    state.lastEndedPartId != current.id
                else {
                    return
                }

                state.openPart = OpenPart(partId: current.id, start: accumulator.totals)
                onPartOpened?(current.id)
            }
        }

        /// Closes and reports the open part, and stops the tracker from opening any part again, since its
        /// observers can outlive retirement by a main turn.
        ///
        /// - Returns: Whether a part was open and has now been reported.
        @discardableResult
        func invalidate() -> Bool {
            lock.locked {
                state.isInvalidated = true
                guard let partId = state.openPart?.partId else { return false }

                state.lastEndedPartId = partId
                closeLocked()
                return true
            }
        }

        // MARK: - Private

        private struct OpenPart {
            let partId: EmbraceIdentifier
            /// The accumulator's totals when the part opened.
            let start: SmoothnessFrameCounts
        }

        private struct TrackerState {
            var openPart: OpenPart?
            /// The last part that ended, which must not be opened again.
            var lastEndedPartId: EmbraceIdentifier?
            /// Set by `invalidate()`. No part opens once it's set.
            var isInvalidated = false
        }

        /// Raw notification name to avoid a direct UIKit dependency.
        private static let didBecomeActiveNotification =
            Notification.Name("UIApplicationDidBecomeActiveNotification")

        private let accumulator: FrameAccumulator
        private let currentSession: () -> EmbraceSession?
        private let notificationCenter: NotificationCenter
        private let embraceNotificationCenter: NotificationCenter
        private let lock = UnfairLock()
        private var state = TrackerState()

        /// Must be called with `lock` held.
        private func closeLocked() {
            guard let part = state.openPart else { return }

            state.openPart = nil
            onPartClosed?(part.partId, accumulator.totals - part.start)
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
                self?.open()
            }
        }

        /// Posted synchronously with `SessionController`'s lock held, while the part's session span is
        /// still open. Records the part as ended if it is open or current, so a late open is ignored.
        @objc private func sessionPartWillEnd(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession else { return }

            lock.locked {
                let isOpen = state.openPart?.partId == session.id
                guard isOpen || currentSession()?.id == session.id else { return }

                state.lastEndedPartId = session.id
                guard isOpen else { return }

                closeLocked()
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
