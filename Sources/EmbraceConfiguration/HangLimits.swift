//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// HangLimits manages limits for the app hangs generated through the SDK
public struct HangLimits: Equatable {

    /// Maximum number of captured hangs in a session.
    public let hangPerSession: UInt

    /// Maximum number of samples captures per hang.
    public let samplesPerHang: UInt

    /// Collects crash reports for Hangs that do not recover.
    public let reportsWatchdogEvents: Bool

    public init(
        hangPerSession: UInt = 200,
        samplesPerHang: UInt = 0,
        reportsWatchdogEvents: Bool = false
    ) {
        self.hangPerSession = hangPerSession
        self.samplesPerHang = samplesPerHang
        self.reportsWatchdogEvents = reportsWatchdogEvents
    }

    public static func == (lhs: HangLimits, rhs: HangLimits) -> Bool {
        return lhs.hangPerSession == rhs.hangPerSession && lhs.samplesPerHang == rhs.samplesPerHang && lhs.reportsWatchdogEvents == rhs.reportsWatchdogEvents
    }
}
