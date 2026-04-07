//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Protocol for objects that observe hang detection events.
///
/// - `hangStarted`: Called when a hang is first detected.
/// - `hangUpdated`: Called periodically while a hang persists (not used by `FrameRateMonitor`).
/// - `hangEnded`: Called when the hang resolves.
public protocol HangObserver: AnyObject {
    func hangStarted(at: Date, duration: TimeInterval)
    func hangUpdated(at: Date, duration: TimeInterval)
    func hangEnded(at: Date, duration: TimeInterval)
}

public extension HangObserver {
    /// Default no-op. `FrameRateMonitor` uses retroactive detection and never calls this method.
    func hangUpdated(at: Date, duration: TimeInterval) {}
}
