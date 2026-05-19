//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// HangLimits manages limits for the app hangs generated through the SDK
public struct HangLimits: Equatable {

    /// Minimum duration (in seconds) a frame delay must exceed to be reported as a hang.
    public let hangThreshold: TimeInterval

    /// Maximum number of captured hangs in a session.
    public let hangPerSession: UInt

    /// Collects crash reports for Hangs that do not recover.
    public let reportsWatchdogEvents: Bool

    public init(
        hangThreshold: TimeInterval = 0.249,
        hangPerSession: UInt = 20,
        reportsWatchdogEvents: Bool = false
    ) {
        self.hangThreshold = hangThreshold
        self.hangPerSession = hangPerSession
        self.reportsWatchdogEvents = reportsWatchdogEvents
    }
}
