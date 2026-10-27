//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// A tick with its lateness and dropped frames.
    struct MeasuredTick {

        let tick: FrameTimingSource.Tick

        let lateness: TimeInterval

        let droppedFrames: Int

        init(_ tick: FrameTimingSource.Tick) {
            let late = Self.lateness(of: tick)
            self.tick = tick
            self.lateness = late
            self.droppedFrames = Self.droppedFrames(lateness: late, frameInterval: tick.frameInterval)
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
    }

#endif  // !os(watchOS) && !os(macOS)
