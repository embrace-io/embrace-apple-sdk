//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class ManualSessionLifecycle: SessionLifecycle {

    weak var controller: SessionControllable?
    var active = false

    init(controller: SessionControllable) {
        self.controller = controller
    }

    func setup() {
        active = true
    }

    func stop() {
        active = false
    }

    func startSession() {
        guard active else {
            return
        }

        controller?.startSession(state: .foreground)
    }

    func endSession() {
        guard active else {
            return
        }

        controller?.endSession()
    }
}
