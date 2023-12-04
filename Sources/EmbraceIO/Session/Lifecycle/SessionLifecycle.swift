//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol SessionLifecycle {

    /// The underlying SessionController.
    /// It is recommended to use a weak reference when storing this property to prevent retain cycles
    var controller: SessionControllable? { get }

    /// Method called during SDK setup for initialization purposes
    func setup()

    /// An explicit method to create a new session
    func startSession()

    /// Allow for an explicit
    func endSession()
}
