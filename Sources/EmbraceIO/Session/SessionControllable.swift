//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

/// Protocol for managing sessions.
/// See ``SessionController`` for main conformance
protocol SessionControllable: AnyObject {

    var currentSession: EmbraceSession? { get }

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession
    func endSession()

    func update(session: EmbraceSession, state: SessionState?, appTerminated: Bool?)
    func update(session: EmbraceSession, state: SessionState?)
    func update(session: EmbraceSession, appTerminated: Bool?)
}

extension SessionControllable {

    func update(session: EmbraceSession, state: SessionState?) {
        update(session: session, state: state, appTerminated: nil)
    }

    func update(session: EmbraceSession, appTerminated: Bool?) {
        update(session: session, state: nil, appTerminated: appTerminated)
    }
}
