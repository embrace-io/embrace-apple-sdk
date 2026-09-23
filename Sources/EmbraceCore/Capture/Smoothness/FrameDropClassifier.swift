//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// Accumulates per-tick frame accounting on behalf of the currently active accumulator.
    ///
    /// `SmoothnessSessionTracker` implements this and plugs itself in as `FrameDropClassifier`'s
    /// `currentAccumulator` for as long as the app's foreground session is active.
    protocol FrameDropAccumulator: AnyObject {

        /// Called exactly once per tick with the number of vsyncs missed on that tick (`0` for an
        /// on-time frame, never negative) and the display's frame duration at the time of the tick.
        ///
        /// Called for every tick, not just late ones, so the accumulator can count expected frames
        /// (`missedVsyncs + 1` per tick) as well as dropped ones.
        func recordFrame(missedVsyncs: Int, frameDuration: TimeInterval)
    }

    /// Converts each `FrameTimingSource` tick into a missed-vsync count and forwards it to
    /// whichever accumulator is current.
    ///
    /// `FrameDropClassifier` has no notion of what owns the accumulator — it only knows about
    /// `currentAccumulator`. While it is `nil`, `handle(delay:frameDuration:)` no-ops.
    ///
    /// Must be used from the main thread.
    final class FrameDropClassifier {

        /// The accumulator for the currently open foreground session, or `nil` when none is open.
        weak var currentAccumulator: FrameDropAccumulator?

        /// Feed this from `FrameTimingSource.onTick`.
        func handle(delay: TimeInterval, frameDuration: TimeInterval) {
            guard let currentAccumulator else { return }
            guard frameDuration > 0 else { return }

            let missedVsyncs = max(0, Int((delay / frameDuration).rounded(.down)))

            currentAccumulator.recordFrame(missedVsyncs: missedVsyncs, frameDuration: frameDuration)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
