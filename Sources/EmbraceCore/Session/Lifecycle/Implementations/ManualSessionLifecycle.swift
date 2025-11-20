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
        assert(Thread.isMainThread, "ManualSessionLifecycle.startSession() must be called on the main thread")

        guard active else {
            return
        }

        controller?.startSession(state: .foreground)
    }

    func endSession() {
        assert(Thread.isMainThread, "ManualSessionLifecycle.endSession() must be called on the main thread")

        guard active else {
            return
        }

        controller?.endSession()
    }
}
