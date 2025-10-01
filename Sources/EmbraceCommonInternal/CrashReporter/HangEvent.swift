//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Watchdog Reporting
public struct WatchdogEvent {
    public let timestamp: NanosecondClock
    public let duration: NanosecondClock

    public init(timestamp: NanosecondClock, duration: NanosecondClock) {
        self.timestamp = timestamp
        self.duration = duration
    }
}

// These are sent when a hang statrs, is updated and ends. The object of the notification is the WatchdogEvent.
extension Notification.Name {
    public static let hangEventStarted = Notification.Name("io.embrace.hang.started")
    public static let hangEventUpdated = Notification.Name("io.embrace.hang.updated")
    public static let hangEventEnded = Notification.Name("io.embrace.hang.ended")
}
