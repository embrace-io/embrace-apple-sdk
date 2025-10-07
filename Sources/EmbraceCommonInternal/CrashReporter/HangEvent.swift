//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Watchdog Reporting

/// Represents an event captured by the watchdog mechanism,
/// which tracks main thread hangs or stalls.
///
/// A `WatchdogEvent` encapsulates:
/// - The `timestamp` at which the hang event was detected.
/// - The total `duration` of the hang
///
/// These values can be used to correlate hang reports with
/// other telemetry such as spans, metrics, or crash reports.
public struct WatchdogEvent {

    /// The timestamp at which the hang was first detected.
    public let timestamp: EmbraceClock

    /// The total duration the main thread was blocked.
    /// This value increases for updated hang events, and remains constant once the hang ends.
    public let duration: EmbraceClock

    /// Creates a new `WatchdogEvent` instance.
    ///
    /// - Parameters:
    ///   - timestamp: The time when the hang was first observed.
    ///   - duration: The hang duration.
    public init(timestamp: EmbraceClock, duration: EmbraceClock) {
        self.timestamp = timestamp
        self.duration = duration
    }
}

// MARK: - Notifications

/// Notifications emitted to signal the lifecycle of a hang event.
///
/// These notifications are posted by the watchdog subsystem:
/// - When a hang starts.
/// - When it is updated (duration increased while still hanging).
/// - When it ends (the main thread recovers).
///
/// The `object` attached to each notification is a `WatchdogEvent`
/// describing the timestamp and duration of the event.
extension Notification.Name {

    /// Posted when the watchdog detects the start of a hang.
    ///
    /// The notification’s `object` is a `WatchdogEvent` representing the
    /// initial hang state (timestamp and starting duration).
    public static let hangEventStarted = Notification.Name("io.embrace.hang.started")

    /// Posted when a hang event remains ongoing and its duration updates.
    ///
    /// The notification’s `object` is a `WatchdogEvent` containing the
    /// current timestamp and the updated duration.
    public static let hangEventUpdated = Notification.Name("io.embrace.hang.updated")

    /// Posted when a hang ends, indicating that the main thread recovered.
    ///
    /// The notification’s `object` is a `WatchdogEvent` representing the
    /// final timestamp and total hang duration.
    public static let hangEventEnded = Notification.Name("io.embrace.hang.ended")
}
