//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import QuartzCore

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceConfiguration
        import EmbraceSemantics
    #endif

    /// Emits each focal moment the tracker reports as a completed, private `smoothness` span.
    ///
    /// Moments are tagged with the part current when they end and buffered, then created as spans on
    /// `queue`, so span creation never runs on the tick handler. One whose part is no longer current by
    /// then is dropped rather than attributed to the next part. `.embraceSessionPartWillEndSync`
    /// interrupts the open moment and creates the ending part's spans synchronously, before the part's
    /// payload is built. Moments that end after that, while the part is still briefly current, are
    /// dropped.
    ///
    /// Each drain holds `drainLock` from choosing its part until its spans are created, and spans are
    /// created for the tagged part rather than whichever is current. So a part can't end between an
    /// async drain's check and its spans: the will-end drain waits for it, and its spans are in the
    /// part's payload.
    ///
    /// Lock order: the tracker's lock or `drainLock`, then `lock`. The tracker's lock is never taken
    /// with `drainLock` held, and spans are created with only `drainLock` held.
    final class FocalMomentEmitter {

        /// - Parameters:
        ///   - tracker: Its `onMoment` is set to feed this emitter.
        ///   - currentSession: Returns the current session part. Called with the tracker's lock held,
        ///     sometimes from the will-end hook with `SessionController`'s lock held, so it must only take
        ///     the controller's session mutex.
        ///   - otel: Where spans are created.
        ///   - embraceNotificationCenter: Where `.embraceSessionPartWillEndSync` is posted.
        ///   - queue: Where buffered moments are created as spans.
        ///   - clockOffset: Seconds to add to a `CACurrentMediaTime` value to get a Unix time.
        init(
            tracker: FocalMomentTracker,
            currentSession: @escaping () -> EmbraceSession?,
            otel: @escaping () -> EmbraceOTelSignalsHandler?,
            embraceNotificationCenter: NotificationCenter,
            queue: DispatchQueue,
            spanLimit: Int = SmoothnessLimits.defaultSpanLimit,
            clockOffset: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 - CACurrentMediaTime() }
        ) {
            self.tracker = tracker
            self.currentSession = currentSession
            self.otel = otel
            self.embraceNotificationCenter = embraceNotificationCenter
            self.queue = queue
            self.spanLimit = spanLimit
            self.clockOffset = clockOffset

            tracker.onMoment = { [weak self] moment in
                self?.enqueue(moment)
            }

            embraceNotificationCenter.addObserver(
                self,
                selector: #selector(sessionPartWillEnd),
                name: .embraceSessionPartWillEndSync,
                object: nil
            )
        }

        deinit {
            embraceNotificationCenter.removeObserver(self)
        }

        /// Stops emitting. Moments that end later, including the one open now, are dropped.
        func invalidate() {
            embraceNotificationCenter.removeObserver(self)
            lock.locked {
                state.isInvalidated = true
                state.pending = []
            }
        }

        // MARK: - Private

        private struct PendingMoment {
            let session: EmbraceSession
            let moment: FocalMoment
            /// `clockOffset` when the moment ended.
            let clockOffset: TimeInterval
        }

        private struct EmitterState {
            var pending: [PendingMoment] = []
            var isDrainScheduled = false
            var isInvalidated = false
            /// The last part drained by the will-end hook, whose later moments are dropped.
            var endedPartId: EmbraceIdentifier?
            var countedPartId: EmbraceIdentifier?
            var spanCount = 0
        }

        private weak var tracker: FocalMomentTracker?
        private let currentSession: () -> EmbraceSession?
        private let otel: () -> EmbraceOTelSignalsHandler?
        private let embraceNotificationCenter: NotificationCenter
        private let queue: DispatchQueue
        private let spanLimit: Int
        private let clockOffset: () -> TimeInterval
        private let lock = UnfairLock()
        /// Held by each drain from choosing its part until its spans are created.
        private let drainLock = UnfairLock()
        private var state = EmitterState()

        /// Called with the tracker's lock held, on whichever thread ended the moment.
        private func enqueue(_ moment: FocalMoment) {
            guard let session = currentSession() else { return }

            let pending = PendingMoment(session: session, moment: moment, clockOffset: clockOffset())
            let schedulesDrain = lock.locked { () -> Bool in
                guard !state.isInvalidated, state.endedPartId != session.id else { return false }
                state.pending.append(pending)
                guard !state.isDrainScheduled else { return false }
                state.isDrainScheduled = true
                return true
            }

            if schedulesDrain {
                queue.async { [weak self] in
                    self?.drain(endingSession: nil)
                }
            }
        }

        /// Creates spans for the moments buffered for `endingSession`, or for the current part when `nil`,
        /// and drops the rest. Passing `endingSession` also drops that part's later moments.
        private func drain(endingSession: EmbraceSession?) {
            drainLock.locked {
                let isAsync = endingSession == nil
                guard let partId = endingSession?.id ?? currentSession()?.id else {
                    lock.locked {
                        state.pending = []
                        if isAsync { state.isDrainScheduled = false }
                    }
                    return
                }

                let emitted = lock.locked { () -> [PendingMoment] in
                    if isAsync {
                        state.isDrainScheduled = false
                    } else {
                        state.endedPartId = partId
                    }
                    let pending = state.pending
                    state.pending = []
                    return pending.filter { $0.session.id == partId && reserveSpanLocked(partId: partId) }
                }

                emitted.forEach(emit)
            }
        }

        private func reserveSpanLocked(partId: EmbraceIdentifier) -> Bool {
            if state.countedPartId != partId {
                state.countedPartId = partId
                state.spanCount = 0
            }
            guard state.spanCount < spanLimit else { return false }
            state.spanCount += 1
            return true
        }

        private func emit(_ pending: PendingMoment) {
            let moment = pending.moment
            let outcome: String
            switch moment.outcome {
            case .settled: outcome = SpanSemantics.Smoothness.Outcome.settled
            case .interrupted: outcome = SpanSemantics.Smoothness.Outcome.interrupted
            }

            var attributes: EmbraceAttributes = [
                SpanSemantics.keyPrivate: "true",
                SpanSemantics.Smoothness.keyOutcome: outcome,
                SpanSemantics.Smoothness.keyFrameCount: moment.frameCount,
                SpanSemantics.Smoothness.keyNormalizedDroppedFrames: moment.normalizedDroppedFrames,
                SpanSemantics.Smoothness.keyIdleThresholdMs: Self.milliseconds(moment.idleThreshold),
                SpanSemantics.Smoothness.keyHeldIdleThresholdMs: Self.milliseconds(moment.heldIdleThreshold)
            ]
            if let frameTrace = moment.frameTrace {
                attributes[SpanSemantics.Smoothness.keyFrameTrace] = Self.unpaddedBase64(frameTrace)
            }

            _ = try? otel()?.createInternalSpan(
                name: SpanSemantics.Smoothness.focalMomentName,
                type: .smoothness,
                startTime: Date(timeIntervalSince1970: pending.clockOffset + moment.start),
                endTime: Date(timeIntervalSince1970: pending.clockOffset + moment.end),
                attributes: attributes,
                session: pending.session
            )
        }

        private static func milliseconds(_ interval: TimeInterval) -> Int {
            Int((interval * 1000).rounded())
        }

        /// Base64 without padding, matching Android's `NO_PADDING`.
        static func unpaddedBase64(_ data: Data) -> String {
            var encoded = data.base64EncodedString()
            while encoded.hasSuffix("=") {
                encoded.removeLast()
            }
            return encoded
        }

        /// Posted synchronously with `SessionController`'s lock held, while the part is still current.
        @objc private func sessionPartWillEnd(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession else { return }

            tracker?.interrupt()
            drain(endingSession: session)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
