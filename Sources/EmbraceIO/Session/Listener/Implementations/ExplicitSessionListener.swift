//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class ExplicitSessionListener: SessionListener {

    weak var controller: SessionControllable?

    init(controller: SessionControllable) {
        self.controller = controller
    }

    func startSession() {
        guard let controller = controller else {
            return
        }

        let session = controller.createSession(state: .foreground)
        controller.start(session: session)
    }

    func endSession() {
        guard let controller = controller else {
            return
        }

        if let session = controller.currentSession {
            controller.end(session: session)
        }
    }

}
