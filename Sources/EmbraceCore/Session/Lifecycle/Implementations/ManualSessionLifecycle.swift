//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class ManualSessionLifecycle: SessionLifecycle {

    weak var controller: SessionControllable?

    init(controller: SessionControllable) {
        self.controller = controller
    }

    func setup() {
    }

    func start() {

    }

    func startSession() {
        controller?.startSession(state: .foreground)
    }

    func endSession() {
        controller?.endSession()
    }
}
