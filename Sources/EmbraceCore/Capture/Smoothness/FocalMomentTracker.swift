//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    /// A finished focal moment. Times are display-link timestamps (`CACurrentMediaTime` seconds).
    struct FocalMoment: Equatable {

        enum Outcome: Equatable {
            case settled
            case interrupted
        }

        /// The first activity tick's arrival minus its lateness.
        let start: TimeInterval

        /// The last activity tick's arrival.
        let end: TimeInterval

        let outcome: Outcome

        /// Ticks from the first activity tick to the last, inclusive.
        let frameCount: Int

        /// Total lateness of those ticks in 60fps reference frames.
        let normalizedDroppedFrames: Double

        let idleThreshold: TimeInterval

        let heldIdleThreshold: TimeInterval
    }

    /// Tracks focal moments from the ticks it is fed, settling them on the tick handler rather than a timer.
    ///
    /// A moment with no main-thread work or scroll tracking, such as a tap on a dead area, is dropped: touch
    /// phases alone draw nothing, matching Android dropping moments with no rendered frame.
    ///
    /// Ticks arrive on main; `interrupt()` can come from any thread, so one lock guards the state.
    class FocalMomentTracker {

        static let defaultIdleThreshold: TimeInterval = 0.1
        static let defaultHeldIdleThreshold: TimeInterval = 0.5

        /// Called with each moment that settles or is interrupted, on the thread that ended it, with the
        /// tracker's lock held. Must not call back into the tracker.
        var onMoment: ((FocalMoment) -> Void)?

        let idleThreshold: TimeInterval
        let heldIdleThreshold: TimeInterval

        init(
            idleThreshold: TimeInterval = FocalMomentTracker.defaultIdleThreshold,
            heldIdleThreshold: TimeInterval = FocalMomentTracker.defaultHeldIdleThreshold
        ) {
            self.idleThreshold = idleThreshold
            self.heldIdleThreshold = heldIdleThreshold
        }

        func record(_ tick: MeasuredTick, activity: ActivityMonitor.Snapshot) {
            lock.locked { recordLocked(tick, activity: activity) }
        }

        /// Ends the open moment at its last activity tick.
        func interrupt() {
            lock.locked { finishLocked(.interrupted) }
        }

        // MARK: - Private

        private func recordLocked(_ tick: MeasuredTick, activity: ActivityMonitor.Snapshot) {
            let arrival = tick.tick.timestamp

            guard var moment = open else {
                if activity.touchBegan || (activity.touchChanged && activity.activeTouchCount > 0) {
                    var moment = OpenMoment(start: arrival - tick.lateness, lastActivity: arrival)
                    moment.include(tick, activity: activity)
                    open = moment
                }
                return
            }

            if activity.hasActivity {
                moment.include(tick, activity: activity)
                open = moment
                return
            }

            let threshold = activity.activeTouchCount > 0 ? heldIdleThreshold : idleThreshold
            if arrival - moment.lastActivity >= threshold {
                finishLocked(.settled)
                return
            }

            moment.pendingFrameCount += 1
            moment.pendingLateness += tick.lateness
            open = moment
        }

        private struct OpenMoment {
            let start: TimeInterval
            var lastActivity: TimeInterval
            var frameCount = 0
            var lateness: TimeInterval = 0

            /// Ticks without activity since the last activity tick, not yet part of the moment.
            var pendingFrameCount = 0
            var pendingLateness: TimeInterval = 0

            var sawWorkOrTracking = false

            mutating func include(_ tick: MeasuredTick, activity: ActivityMonitor.Snapshot) {
                lastActivity = tick.tick.timestamp
                frameCount += pendingFrameCount + 1
                lateness += pendingLateness + tick.lateness
                pendingFrameCount = 0
                pendingLateness = 0
                sawWorkOrTracking = sawWorkOrTracking || activity.didWork || activity.isTracking
            }
        }

        private static let referenceFrameRate: Double = 60

        private let lock = UnfairLock()
        private var open: OpenMoment?

        private func finishLocked(_ outcome: FocalMoment.Outcome) {
            guard let moment = open else { return }
            open = nil

            guard moment.sawWorkOrTracking else { return }

            onMoment?(
                FocalMoment(
                    start: moment.start,
                    end: moment.lastActivity,
                    outcome: outcome,
                    frameCount: moment.frameCount,
                    normalizedDroppedFrames: moment.lateness * Self.referenceFrameRate,
                    idleThreshold: idleThreshold,
                    heldIdleThreshold: heldIdleThreshold
                ))
        }
    }

#endif  // !os(watchOS) && !os(macOS)
