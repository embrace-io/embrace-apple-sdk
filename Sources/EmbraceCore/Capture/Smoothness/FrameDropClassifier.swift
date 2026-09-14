//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// Accumulates missed-vsync counts on behalf of the currently open focal moment.
    ///
    /// `FocalMomentTracker` implements this and plugs itself in as `FrameDropClassifier`'s
    /// `currentAccumulator` for as long as a focal moment is open.
    protocol FrameDropAccumulator: AnyObject {

        /// Called at most once per tick with the number of vsyncs missed on that tick. Never
        /// called with a non-positive count.
        func addMissedVsyncs(_ count: Int)
    }

    /// Converts each `FrameTimingSource` tick into a missed-vsync count and forwards it to
    /// whichever accumulator is current.
    ///
    /// `FrameDropClassifier` has no notion of a focal moment itself — it only knows about
    /// `currentAccumulator`. While it is `nil`, `handle(delay:frameDuration:)` no-ops.
    ///
    /// Must be used from the main thread.
    final class FrameDropClassifier {

        /// The accumulator for the currently open focal moment, or `nil` when none is open.
        weak var currentAccumulator: FrameDropAccumulator?

        /// Feed this from `FrameTimingSource.onTick`.
        func handle(delay: TimeInterval, frameDuration: TimeInterval) {
            guard let currentAccumulator else { return }
            guard frameDuration > 0 else { return }

            let missedVsyncs = Int((delay / frameDuration).rounded(.down))
            guard missedVsyncs > 0 else { return }

            currentAccumulator.addMissedVsyncs(missedVsyncs)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
