//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Measures how far the device's wall clock has moved relative to the time that actually elapsed.
///
/// The clock holds an *anchor*: one wall-clock reading paired with one monotonic reading taken at
/// the same instant. The monotonic reading cannot be adjusted, so the difference between how far
/// the wall clock advanced and how far the monotonic clock advanced over the same interval is
/// exactly the amount the device clock was changed during it — whether by the user, or by time
/// synchronization correcting a device whose clock had drifted.
///
/// This type does not produce timestamps, and nothing the SDK emits is derived from it. It exists
/// to report how much the device clock moved, not to compensate for it.
public final class EmbraceClock {

    /// A wall-clock reading paired with a monotonic reading taken at the same instant.
    struct Anchor {
        let wall: Date
        let mono: UInt64
    }

    /// Largest drift magnitude, in milliseconds, accepted as a real measurement (~10 years).
    /// Anything beyond this is a broken reading rather than a clock adjustment, and reporting it
    /// would only add noise.
    private static let maxPlausibleDriftMs: Double = 10 * 365 * 24 * 60 * 60 * 1000

    /// Largest disagreement, in milliseconds, tolerated between the two paired samples.
    ///
    /// The four readings take microseconds, so a bigger gap than this means the system clock moved
    /// *during* the measurement and neither sample can be trusted. One millisecond absorbs the case
    /// where the clock simply ticks over to the next millisecond mid-measurement.
    private static let samplingToleranceMs: Double = 1

    private let wallProvider: () -> Date
    private let monoProvider: () -> UInt64
    private let anchor: EmbraceMutex<Anchor>

    /// Creates a clock anchored to the current instant.
    ///
    /// - Parameters:
    ///   - wallProvider: Source of wall-clock readings. Injectable so tests can move the two clocks
    ///                   independently, which is the only way to simulate a clock change.
    ///   - monoProvider: Source of monotonic readings, in nanoseconds.
    public init(
        wallProvider: @escaping () -> Date = Date.init,
        monoProvider: @escaping () -> UInt64 = EmbraceMonotonicTime.nanos
    ) {
        self.wallProvider = wallProvider
        self.monoProvider = monoProvider
        self.anchor = EmbraceMutex(Anchor(wall: wallProvider(), mono: monoProvider()))
    }

    /// Measures the drift accumulated since the current anchor, then re-anchors to the instant of
    /// the measurement so the next call reports only the interval that follows this one.
    ///
    /// Measuring and re-anchoring happen under a single lock, so two callers racing at the same
    /// moment cannot both measure against the same anchor and double-report the same interval.
    ///
    /// - Returns: Signed milliseconds. A positive value means the wall clock ran ahead of the time
    ///   that actually elapsed — it was moved forward during the interval; negative means it was
    ///   moved backwards. `nil` when the reading could not be trusted, in which case the clock is
    ///   re-anchored anyway so one bad sample does not affect the following interval.
    @discardableResult
    public func measureDriftAndReanchor() -> EMBInt? {
        return anchor.withLock { current in
            // Interleaved so the two samples bracket each other: a clock change landing in the
            // middle of the measurement shows up as a disagreement between them.
            let wall1 = wallProvider()
            let mono1 = monoProvider()
            let wall2 = wallProvider()
            let mono2 = monoProvider()

            let result = Self.drift(
                since: current,
                wall1: wall1,
                mono1: mono1,
                wall2: wall2,
                mono2: mono2
            )

            current = Anchor(wall: wall2, mono: mono2)
            return result
        }
    }

    /// Re-anchors to the current instant without measuring.
    public func reanchor() {
        anchor.withLock {
            $0 = Anchor(wall: wallProvider(), mono: monoProvider())
        }
    }

    /// Computes the drift described by two paired samples, or `nil` when they cannot be trusted.
    private static func drift(
        since anchor: Anchor,
        wall1: Date,
        mono1: UInt64,
        wall2: Date,
        mono2: UInt64
    ) -> EMBInt? {

        // A monotonic reading below the anchor is impossible, so a value that low means the source
        // is not behaving as one and nothing derived from it is meaningful.
        guard mono1 >= anchor.mono, mono2 >= anchor.mono else {
            return nil
        }

        guard let drift1 = driftMs(since: anchor, wall: wall1, mono: mono1),
            let drift2 = driftMs(since: anchor, wall: wall2, mono: mono2)
        else {
            return nil
        }

        guard abs(drift1 - drift2) <= samplingToleranceMs else {
            return nil
        }

        let drift = (drift1 + drift2) / 2
        guard abs(drift) <= maxPlausibleDriftMs else {
            return nil
        }

        return EMBInt(drift.rounded())
    }

    /// Milliseconds the wall clock moved beyond the elapsed monotonic time, for one sample.
    /// `nil` when either input is not a finite quantity.
    private static func driftMs(since anchor: Anchor, wall: Date, mono: UInt64) -> Double? {
        let elapsedWallMs = wall.timeIntervalSince(anchor.wall) * 1000
        let elapsedMonoMs = Double(mono - anchor.mono) / 1_000_000

        let drift = elapsedWallMs - elapsedMonoMs
        guard drift.isFinite else {
            return nil
        }

        return drift
    }
}
