//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// HangLimits manages limits for the app hangs generated through the SDK
public struct HangLimits: Equatable {

    // MARK: - Defaults

    /// Default minimum frame delay reported as a hang (≈ Apple's own definition of a hang).
    public static let defaultHangThreshold: TimeInterval = 0.249
    /// Default maximum number of captured hangs per session.
    public static let defaultHangPerSession: UInt = 20
    /// Default for collecting watchdog reports for hangs that do not recover.
    public static let defaultReportsWatchdogEvents = false
    /// Default trigger for the during-block sampler.
    public static let defaultSampleTriggerThreshold: TimeInterval = 0.15
    /// Default poll cadence for the during-block sampler.
    public static let defaultSamplePollInterval: TimeInterval = 0.05

    // MARK: - Bounds
    //
    // Bounds for the remote-config-driven sampler values. The low bounds keep a bad/hostile remote
    // value from driving overly aggressive main-thread suspension. The high bounds are product
    // ceilings that double as a safety rail: the sampler converts these to nanoseconds via
    // `UInt64(seconds * 1_000_000_000)`, which would trap on an out-of-range value. Clamping in
    // `init` means every consumer of `HangLimits` inherits the guarantee.

    public static let minSampleTriggerThreshold: TimeInterval = 0.05  // 50 ms
    public static let maxSampleTriggerThreshold: TimeInterval = 3600  // 1 h
    public static let minSamplePollInterval: TimeInterval = 0.01  // 10 ms
    public static let maxSamplePollInterval: TimeInterval = 60  // 60 s

    /// Fraction of `hangThreshold` used to re-derive `sampleTriggerThreshold` when a remote config is
    /// internally inconsistent (`sampleTriggerThreshold >= hangThreshold`). Matches the ratio the
    /// SDK's own defaults use (0.15 / 0.249 ≈ 0.6), so the during-block snapshot lands well inside the
    /// confirmed hang window.
    static let sampleTriggerFraction: TimeInterval = 0.6

    // MARK: - Values

    /// Minimum duration (in seconds) a frame delay must exceed to be reported as a hang.
    public let hangThreshold: TimeInterval

    /// Maximum number of captured hangs in a session.
    public let hangPerSession: UInt

    /// Collects crash reports for Hangs that do not recover.
    public let reportsWatchdogEvents: Bool

    /// How long (in seconds) the main thread must be continuously busy before the during-block
    /// sampler snapshots it. Capped at ``sampleTriggerFraction`` of `hangThreshold` — a fixed headroom
    /// below the reported-hang threshold so the snapshot lands inside the confirmed window — and
    /// clamped into `[minSampleTriggerThreshold, maxSampleTriggerThreshold]`. A requested value in
    /// `[minSampleTriggerThreshold, cap]` is used as-is. For a degenerately small `hangThreshold` (below
    /// `minSampleTriggerThreshold / sampleTriggerFraction`) the floor takes precedence over the cap.
    public let sampleTriggerThreshold: TimeInterval

    /// How often (in seconds) the background sampler checks main-thread liveness. Clamped into
    /// `[minSamplePollInterval, maxSamplePollInterval]`.
    public let samplePollInterval: TimeInterval

    /// Creates a new `HangLimits`.
    /// - Parameters:
    ///   - hangThreshold: Minimum duration (in seconds) a frame delay must exceed to be reported as a hang.
    ///   - hangPerSession: Maximum number of captured hangs in a session.
    ///   - reportsWatchdogEvents: Whether crash reports are collected for hangs that do not recover.
    ///   - sampleTriggerThreshold: How long the main thread must be busy before the during-block
    ///     sampler snapshots it. Clamped as described on the property.
    ///   - samplePollInterval: How often the background sampler checks main-thread liveness. Clamped
    ///     as described on the property.
    public init(
        hangThreshold: TimeInterval = HangLimits.defaultHangThreshold,
        hangPerSession: UInt = HangLimits.defaultHangPerSession,
        reportsWatchdogEvents: Bool = HangLimits.defaultReportsWatchdogEvents,
        sampleTriggerThreshold: TimeInterval = HangLimits.defaultSampleTriggerThreshold,
        samplePollInterval: TimeInterval = HangLimits.defaultSamplePollInterval
    ) {
        let resolvedHangThreshold = HangLimits.sanitized(
            hangThreshold, fallback: HangLimits.defaultHangThreshold)

        self.hangThreshold = resolvedHangThreshold
        self.hangPerSession = hangPerSession
        self.reportsWatchdogEvents = reportsWatchdogEvents
        self.sampleTriggerThreshold = HangLimits.resolvedSampleTrigger(
            sampleTriggerThreshold, hangThreshold: resolvedHangThreshold)
        self.samplePollInterval = HangLimits.clamped(
            samplePollInterval,
            fallback: HangLimits.defaultSamplePollInterval,
            min: HangLimits.minSamplePollInterval,
            max: HangLimits.maxSamplePollInterval
        )
    }

    /// Effective during-block trigger for a `requested` value and an already-sanitized `hangThreshold`.
    /// Always capped at ``sampleTriggerFraction`` of `hangThreshold` (a fixed headroom below the
    /// reported-hang threshold), then clamped into `[minSampleTriggerThreshold, maxSampleTriggerThreshold]`.
    /// A non-finite request falls back to the default (itself subject to the cap). `max(…, min…)` on
    /// the ceiling keeps it from dropping below the floor for a degenerately small `hangThreshold`, so
    /// the floor wins there; it also keeps the value bounded, so an unbounded `hangThreshold` can't
    /// reintroduce the ns-conversion overflow downstream.
    private static func resolvedSampleTrigger(
        _ requested: TimeInterval, hangThreshold: TimeInterval
    ) -> TimeInterval {
        let base = requested.isFinite ? requested : defaultSampleTriggerThreshold
        let ceiling = Swift.max(
            Swift.min(hangThreshold * sampleTriggerFraction, maxSampleTriggerThreshold),
            minSampleTriggerThreshold)
        return Swift.min(Swift.max(base, minSampleTriggerThreshold), ceiling)
    }

    /// A finite, positive value passes through unchanged; anything else falls back to `fallback`.
    private static func sanitized(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        value.isFinite && value > 0 ? value : fallback
    }

    /// A finite value clamped into `[minimum, maximum]`; a non-finite value falls back to `fallback`.
    private static func clamped(
        _ value: TimeInterval,
        fallback: TimeInterval,
        min minimum: TimeInterval,
        max maximum: TimeInterval
    ) -> TimeInterval {
        guard value.isFinite else { return fallback }
        return Swift.min(Swift.max(value, minimum), maximum)
    }
}
