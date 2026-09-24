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

        /// Called exactly once per tick with how late that tick's frame arrived, in seconds (`0` for an
        /// on-time frame, never negative).
        ///
        /// Called for every tick, not just late ones, so the accumulator can count rendered frames as
        /// well as dropped time.
        func recordFrame(lateBy: TimeInterval)
    }

    /// Converts each `FrameTimingSource` tick into a non-negative lateness and forwards it to whichever
    /// accumulator is current.
    ///
    /// Lateness is passed through as a continuous duration rather than quantized into whole missed
    /// vsyncs, so partial-frame drops aren't lost and the accumulator can normalize to any reference
    /// frame rate without rounding drift.
    ///
    /// `FrameDropClassifier` has no notion of what owns the accumulator — it only knows about
    /// `currentAccumulator`. While it is `nil`, `handle(delay:)` no-ops.
    ///
    /// Must be used from the main thread.
    final class FrameDropClassifier {

        /// The accumulator for the currently open foreground session, or `nil` when none is open.
        weak var currentAccumulator: FrameDropAccumulator?

        /// Feed this from `FrameTimingSource.onTick`.
        func handle(delay: TimeInterval) {
            guard let currentAccumulator else { return }

            currentAccumulator.recordFrame(lateBy: max(0, delay))
        }
    }

#endif  // !os(watchOS) && !os(macOS)
