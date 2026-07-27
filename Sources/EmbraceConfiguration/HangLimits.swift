//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// HangLimits manages limits for the app hangs generated through the SDK
@objc public class HangLimits: NSObject {

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

    // MARK: - Values

    /// Minimum duration (in seconds) a frame delay must exceed to be reported as a hang.
    public let hangThreshold: TimeInterval

    /// Maximum number of captured hangs in a session.
    public let hangPerSession: UInt

    /// Collects crash reports for Hangs that do not recover.
    public let reportsWatchdogEvents: Bool

    /// How long (in seconds) the main thread must be continuously busy before the during-block
    /// sampler snapshots it. Sits below `hangThreshold` so the snapshot lands inside the hang the
    /// detector later confirms. Clamped into `[minSampleTriggerThreshold, maxSampleTriggerThreshold]`.
    public let sampleTriggerThreshold: TimeInterval

    /// How often (in seconds) the background sampler checks main-thread liveness. Clamped into
    /// `[minSamplePollInterval, maxSamplePollInterval]`.
    public let samplePollInterval: TimeInterval

    public init(
        hangThreshold: TimeInterval = HangLimits.defaultHangThreshold,
        hangPerSession: UInt = HangLimits.defaultHangPerSession,
        reportsWatchdogEvents: Bool = HangLimits.defaultReportsWatchdogEvents,
        sampleTriggerThreshold: TimeInterval = HangLimits.defaultSampleTriggerThreshold,
        samplePollInterval: TimeInterval = HangLimits.defaultSamplePollInterval
    ) {
        self.hangThreshold = HangLimits.sanitized(hangThreshold, fallback: HangLimits.defaultHangThreshold)
        self.hangPerSession = hangPerSession
        self.reportsWatchdogEvents = reportsWatchdogEvents
        self.sampleTriggerThreshold = HangLimits.clamped(
            sampleTriggerThreshold,
            fallback: HangLimits.defaultSampleTriggerThreshold,
            min: HangLimits.minSampleTriggerThreshold,
            max: HangLimits.maxSampleTriggerThreshold
        )
        self.samplePollInterval = HangLimits.clamped(
            samplePollInterval,
            fallback: HangLimits.defaultSamplePollInterval,
            min: HangLimits.minSamplePollInterval,
            max: HangLimits.maxSamplePollInterval
        )
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

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(hangThreshold)
        hasher.combine(hangPerSession)
        hasher.combine(reportsWatchdogEvents)
        hasher.combine(sampleTriggerThreshold)
        hasher.combine(samplePollInterval)
        return hasher.finalize()
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Self else {
            return false
        }
        return hangThreshold == other.hangThreshold
            && hangPerSession == other.hangPerSession
            && reportsWatchdogEvents == other.reportsWatchdogEvents
            && sampleTriggerThreshold == other.sampleTriggerThreshold
            && samplePollInterval == other.samplePollInterval
    }
}
