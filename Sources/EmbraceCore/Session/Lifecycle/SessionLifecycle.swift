//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Notified the instant the app changes state, in the ordering the session machinery guarantees.
///
/// This exists because ordering *is* the contract for anything that has to record something as the
/// final entry of the outgoing session part. `SessionController.endSessionNoLock` closes state spans
/// before it ends the part span, and posts its notifications afterwards — so every observer-based
/// seam in the SDK fires too late to write into the part that is going away.
protocol AppStateObserver: AnyObject {

    /// The app is backgrounding. Called **before** any session work, so the outgoing part is still
    /// open and can still record.
    func appWillBackground(at time: Date)

    /// The app has foregrounded. Called **after** session work, so a new part already exists and
    /// receives whatever this records.
    func appDidForeground(at time: Date)
}

protocol SessionLifecycle {

    /// Registers the observer notified on app-state changes.
    ///
    /// Defaulted to a no-op: only the real app-state lifecycle can honour the ordering above, and
    /// lifecycles driven manually have no app state to report.
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
