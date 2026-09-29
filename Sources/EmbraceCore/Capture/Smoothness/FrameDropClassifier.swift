//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// Accumulates per-tick frame accounting on behalf of the currently active accumulator.
    ///
    /// `SmoothnessSessionTracker` implements this and plugs itself in as `FrameDropClassifier`'s
    /// `currentAccumulator` for its whole lifetime, ignoring ticks while no foreground session is open.
    protocol FrameDropAccumulator: AnyObject {

        /// Called exactly once per tick with how late that tick's frame arrived, in seconds (`0` for an
        /// on-time frame, never negative).
        ///
        /// Called for every tick, not just late ones, so the accumulator can count ticks as well as
        /// dropped time.
        func recordFrame(lateBy: TimeInterval)
    }

    /// Converts each `FrameTimingSource` tick into a non-negative lateness and forwards it to whichever
    /// accumulator is current.
    ///
    /// Lateness is passed through as a continuous duration rather than quantized into whole missed
    /// vsyncs, so partial-frame drops aren't lost and the accumulator can normalize to any reference
    /// frame rate without rounding drift. Two corrections are applied first, so that time which isn't a
    /// dropped frame doesn't add up over long sessions:
    /// - **Refresh rate step-down.** When the frame interval grows between ticks (ProMotion adaptive
    ///   refresh, Low Power Mode, thermal caps), the tick lands up to that growth after the previous
    ///   `targetTimestamp` even though no frame was missed. The growth is subtracted.
    /// - **Noise floor.** Ticks land on vsync boundaries, so a real miss is late by at least about one
    ///   frame interval. Lateness below `noiseFloorFraction` of the tick's frame interval is scheduling
    ///   jitter and counts as `0`. Lateness at or above it is passed through unchanged.
    ///
    /// Only main-thread lateness is measured: see `FrameTimingSource`.
    ///
    /// `FrameDropClassifier` has no notion of what owns the accumulator — it only knows about
    /// `currentAccumulator`. While it is `nil`, `handle(_:)` no-ops.
    ///
    /// Must be used from the main thread.
    final class FrameDropClassifier {

        /// Lateness below this fraction of the tick's frame interval counts as on time.
        static let noiseFloorFraction: Double = 0.5

        /// The accumulator ticks are forwarded to, or `nil` for none.
        weak var currentAccumulator: FrameDropAccumulator?

        /// Feed this from `FrameTimingSource.onTick`.
        func handle(_ tick: FrameTimingSource.Tick) {
            guard let currentAccumulator else { return }

            currentAccumulator.recordFrame(lateBy: Self.lateness(of: tick))
        }

        /// The tick's lateness after the rate step-down and noise-floor corrections. Never negative.
        static func lateness(of tick: FrameTimingSource.Tick) -> TimeInterval {
            let rateStepDown = max(0, tick.frameInterval - tick.previousFrameInterval)
            let late = tick.delay - rateStepDown

            return late < noiseFloorFraction * tick.frameInterval ? 0 : max(0, late)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
