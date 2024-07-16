//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal

@testable import EmbraceCore

class SpySessionController: SessionControllable {
    var currentSession: SessionRecord?

    init(currentSession: SessionRecord? = nil) {
        self.currentSession = currentSession
    }

    func startSession(state: SessionState) -> SessionRecord {
        return currentSession!
    }

    func endSession() -> Date { Date() }
    func update(state: SessionState) {}
    func update(appTerminated: Bool) {}
}
