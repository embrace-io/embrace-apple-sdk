//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol SessionLifecycle {

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
