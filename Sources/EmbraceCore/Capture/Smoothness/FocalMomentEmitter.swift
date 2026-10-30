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
    /// payload is built.
    ///
    /// Lock order: the tracker's lock, then this one. Spans are created with neither held.
    final class FocalMomentEmitter {

        /// - Parameters:
        ///   - tracker: Its `onMoment` is set to feed this emitter.
        ///   - currentPartId: Returns the current session part's id. Called with the tracker's lock held,
        ///     and from the will-end hook with `SessionController`'s lock held, so it must only take the
        ///     controller's session mutex.
        ///   - otel: Where spans are created.
        ///   - embraceNotificationCenter: Where `.embraceSessionPartWillEndSync` is posted.
        ///   - queue: Where buffered moments are created as spans.
        ///   - clockOffset: Seconds to add to a `CACurrentMediaTime` value to get a Unix time.
        init(
            tracker: FocalMomentTracker,
            currentPartId: @escaping () -> EmbraceIdentifier?,
            otel: @escaping () -> EmbraceOTelSignalsHandler?,
            embraceNotificationCenter: NotificationCenter,
            queue: DispatchQueue,
            spanLimit: Int = SmoothnessLimits.defaultSpanLimit,
            clockOffset: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 - CACurrentMediaTime() }
        ) {
            self.tracker = tracker
            self.currentPartId = currentPartId
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
            let partId: EmbraceIdentifier
            let moment: FocalMoment
            /// `clockOffset` when the moment ended.
            let clockOffset: TimeInterval
        }

        private struct EmitterState {
            var pending: [PendingMoment] = []
            var isDrainScheduled = false
            var isInvalidated = false
            var countedPartId: EmbraceIdentifier?
            var spanCount = 0
        }

        private weak var tracker: FocalMomentTracker?
        private let currentPartId: () -> EmbraceIdentifier?
        private let otel: () -> EmbraceOTelSignalsHandler?
        private let embraceNotificationCenter: NotificationCenter
        private let queue: DispatchQueue
        private let spanLimit: Int
        private let clockOffset: () -> TimeInterval
        private let lock = UnfairLock()
        private var state = EmitterState()

        /// Called with the tracker's lock held, on whichever thread ended the moment.
        private func enqueue(_ moment: FocalMoment) {
            guard let partId = currentPartId() else { return }

            let pending = PendingMoment(partId: partId, moment: moment, clockOffset: clockOffset())
            let schedulesDrain = lock.locked { () -> Bool in
                guard !state.isInvalidated else { return false }
                state.pending.append(pending)
                guard !state.isDrainScheduled else { return false }
                state.isDrainScheduled = true
                return true
            }

            if schedulesDrain {
                queue.async { [weak self] in
                    self?.drain(partId: nil)
                }
            }
        }

        /// Creates spans for the moments buffered for `partId`, or for the current part when `nil`, and
        /// drops the rest.
        private func drain(partId: EmbraceIdentifier?) {
            let isAsync = partId == nil
            guard let partId = partId ?? currentPartId() else {
                lock.locked {
                    state.pending = []
                    if isAsync { state.isDrainScheduled = false }
                }
                return
            }

            let emitted = lock.locked { () -> [PendingMoment] in
                if isAsync { state.isDrainScheduled = false }
                let pending = state.pending
                state.pending = []
                return pending.filter { $0.partId == partId && reserveSpanLocked(partId: partId) }
            }

            emitted.forEach(emit)
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

            _ = try? otel()?.createInternalSpan(
                name: SpanSemantics.Smoothness.focalMomentName,
                type: .smoothness,
                startTime: Date(timeIntervalSince1970: pending.clockOffset + moment.start),
                endTime: Date(timeIntervalSince1970: pending.clockOffset + moment.end),
                attributes: [
                    SpanSemantics.keyPrivate: "true",
                    SpanSemantics.Smoothness.keyOutcome: outcome,
                    SpanSemantics.Smoothness.keyFrameCount: moment.frameCount,
                    SpanSemantics.Smoothness.keyNormalizedDroppedFrames: moment.normalizedDroppedFrames,
                    SpanSemantics.Smoothness.keyIdleThresholdMs: Self.milliseconds(moment.idleThreshold),
                    SpanSemantics.Smoothness.keyHeldIdleThresholdMs: Self.milliseconds(moment.heldIdleThreshold)
                ]
            )
        }

        private static func milliseconds(_ interval: TimeInterval) -> Int {
            Int((interval * 1000).rounded())
        }

        /// Posted synchronously with `SessionController`'s lock held, while the part is still current.
        @objc private func sessionPartWillEnd(_ notification: Notification) {
            guard let session = notification.object as? EmbraceSession else { return }

            tracker?.interrupt()
            drain(partId: session.id)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
