//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

/// Protocol for managing sessions.
/// See ``SessionController`` for main conformance
protocol SessionControllable: AnyObject {

    var currentSession: EmbraceSession? { get }

    func createSession(state: SessionState) -> EmbraceSession

    func start(session: EmbraceSession, at startAt: Date)
    func start(session: EmbraceSession)

    func end(session: EmbraceSession, at endAt: Date)
    func end(session: EmbraceSession)

    func update(session: EmbraceSession, state: SessionState?, appTerminated: Bool?)
    func update(session: EmbraceSession, state: SessionState?)
    func update(session: EmbraceSession, appTerminated: Bool?)
}

extension SessionControllable {

    func start(session: EmbraceSession) {
        start(session: session, at: Date())
    }

    func end(session: EmbraceSession) {
        end(session: session, at: Date())
    }

    func update(session: EmbraceSession, state: SessionState?) {
        update(session: session, state: state, appTerminated: nil)
    }

    func update(session: EmbraceSession, appTerminated: Bool?) {
        update(session: session, state: nil, appTerminated: appTerminated)
    }

}
