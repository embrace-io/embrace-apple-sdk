//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// HangLimits manages limits for the app hangs generated through the SDK
@objc public class HangLimits: NSObject {

    /// Minimum duration (in seconds) a frame delay must exceed to be reported as a hang.
    public let hangThreshold: TimeInterval

    /// Maximum number of captured hangs in a session.
    public let hangPerSession: UInt

    /// Collects crash reports for Hangs that do not recover.
    public let reportsWatchdogEvents: Bool

    /// How long (in seconds) the main thread must be continuously busy before the during-block
    /// sampler snapshots it. Sits below `hangThreshold` so the snapshot lands inside the hang the
    /// detector later confirms. The SDK clamps this up to a compiled-in minimum before use.
    public let sampleTriggerThreshold: TimeInterval

    /// How often (in seconds) the background sampler checks main-thread liveness. The SDK clamps
    /// this up to a compiled-in minimum before use.
    public let samplePollInterval: TimeInterval

    public init(
        hangThreshold: TimeInterval = 0.249,
        hangPerSession: UInt = 20,
        reportsWatchdogEvents: Bool = false,
        sampleTriggerThreshold: TimeInterval = 0.15,
        samplePollInterval: TimeInterval = 0.05
    ) {
        self.hangThreshold = hangThreshold
        self.hangPerSession = hangPerSession
        self.reportsWatchdogEvents = reportsWatchdogEvents
        self.sampleTriggerThreshold = sampleTriggerThreshold
        self.samplePollInterval = samplePollInterval
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
