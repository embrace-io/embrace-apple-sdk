//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    /// Whole-frame counts at the display's native refresh rate, either running totals or the difference
    /// between two snapshots of them.
    struct SmoothnessFrameCounts: Equatable {

        /// Frame intervals the main thread overran.
        var droppedFrames = 0

        /// One per tick, plus each dropped frame.
        ///
        /// The display link fires at the display's refresh rate whether or not the app draws, so an idle
        /// screen still adds 60 or 120 per second. Android only counts rendered frames.
        var expectedFrames = 0

        /// Ticks later than the hang threshold.
        var hangCount = 0

        static func - (lhs: SmoothnessFrameCounts, rhs: SmoothnessFrameCounts) -> SmoothnessFrameCounts {
            SmoothnessFrameCounts(
                droppedFrames: lhs.droppedFrames - rhs.droppedFrames,
                expectedFrames: lhs.expectedFrames - rhs.expectedFrames,
                hangCount: lhs.hangCount - rhs.hangCount
            )
        }
    }

    /// App-wide running totals of dropped and expected frames. Session parts and screens snapshot the
    /// totals when they open and report the difference when they close.
    ///
    /// Fed on main from `FrameTimingSource.onTick`; `totals` can be read from any thread.
    final class FrameAccumulator {

        init(hangThreshold: TimeInterval) {
            self.state = State(hangThreshold: hangThreshold)
        }

        /// Sets the lateness past which a tick counts as a hang. It doesn't cap the tick's dropped frames.
        func setHangThreshold(_ hangThreshold: TimeInterval) {
            lock.locked { state.hangThreshold = hangThreshold }
        }

        var totals: SmoothnessFrameCounts {
            lock.locked { state.totals }
        }

        func record(_ tick: FrameTimingSource.Tick) {
            let late = Self.lateness(of: tick)
            let dropped = Self.droppedFrames(lateness: late, frameInterval: tick.frameInterval)

            lock.locked {
                state.totals.droppedFrames += dropped
                state.totals.expectedFrames += 1 + dropped
                if late > state.hangThreshold {
                    state.totals.hangCount += 1
                }
            }
        }

        // MARK: - Frame math

        /// Lateness below this fraction of the tick's frame interval counts as on time.
        static let noiseFloorFraction: Double = 0.5

        /// The tick's lateness, never negative, after two corrections that keep time which isn't a
        /// dropped frame from adding up over long parts:
        /// - **Refresh rate step-down.** When the frame interval grows between ticks (ProMotion adaptive
        ///   refresh, Low Power Mode, thermal caps), the tick lands up to that growth after the previous
        ///   `targetTimestamp` even though no frame was missed. The growth is subtracted.
        /// - **Noise floor.** Ticks land on vsync boundaries, so a real miss is late by at least about one
        ///   frame interval. Lateness below `noiseFloorFraction` of the tick's frame interval is scheduling
        ///   jitter and counts as `0`.
        static func lateness(of tick: FrameTimingSource.Tick) -> TimeInterval {
            let rateStepDown = max(0, tick.frameInterval - tick.previousFrameInterval)
            let late = tick.delay - rateStepDown

            return late < noiseFloorFraction * tick.frameInterval ? 0 : max(0, late)
        }

        /// Whole frame intervals in `lateness`, rounded to the nearest.
        ///
        /// Android uses `ceil`, which suits its real render durations. Tick lateness lands on vsync
        /// multiples plus jitter, so `ceil` would count a tick 1.0001 intervals late as 2 dropped frames.
        /// With the noise floor, any non-zero lateness rounds to at least 1.
        static func droppedFrames(lateness: TimeInterval, frameInterval: TimeInterval) -> Int {
            guard lateness > 0, frameInterval > 0 else { return 0 }

            return Int((lateness / frameInterval).rounded())
        }

        // MARK: - Private

        private struct State {
            var hangThreshold: TimeInterval
            var totals = SmoothnessFrameCounts()
        }

        private let lock = UnfairLock()
        private var state: State
    }

#endif  // !os(watchOS) && !os(macOS)
