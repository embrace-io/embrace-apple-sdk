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
    /// Fed on main from the tick handler; `totals` can be read from any thread.
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

        func record(_ tick: MeasuredTick) {
            lock.locked {
                state.totals.droppedFrames += tick.droppedFrames
                state.totals.expectedFrames += 1 + tick.droppedFrames
                if tick.lateness > state.hangThreshold {
                    state.totals.hangCount += 1
                }
            }
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
