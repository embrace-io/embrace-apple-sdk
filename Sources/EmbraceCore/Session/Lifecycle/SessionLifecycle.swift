//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Notified the instant the app changes state, in the ordering the session machinery guarantees.
///
/// Ordering *is* the contract here: this is for work that must land as the final entry of the
/// outgoing part. The `.embraceSessionPartWillEnd` notification cannot serve — it is posted with
/// `DispatchQueue.main.async`, so it carries no ordering guarantee against the part being closed.
protocol AppStateObserver: AnyObject {

    /// The app is backgrounding. Called **before** any session work, so the outgoing part is still
    /// open and can still record.
    func appWillBackground(at time: Date)

    /// The app has foregrounded. Called **after** the session machinery, so if foregrounding started
    /// a new part this lands in it. It does not always start one: an already-foreground app, and a
    /// cold start inside the launch grace period, both reuse the current part.
    func appDidForeground(at time: Date)
}

protocol SessionLifecycle {

    /// Registers the observer notified on app-state changes. Defaulted to a no-op — a manually
    /// driven lifecycle has no app state to report.
    func setAppStateObserver(_ observer: AppStateObserver?)

    /// The underlying SessionController.
    /// It is recommended to use a weak reference when storing this property to prevent retain cycles
    var controller: SessionControllable? { get }

    /// Method called during ``Embrace.init``
    func setup()

    /// Prevents the lifecycle from starting new sessions
    func stop()

    /// An explicit method to create a new session
    func startSession()

    /// Allow for an explicit
    func endSession()
}

extension SessionLifecycle {
    func setAppStateObserver(_ observer: AppStateObserver?) {}
}
