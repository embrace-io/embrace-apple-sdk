//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceIO
import EmbraceCommon

class MockSessionController: SessionControllable {

    // Properties for mocking
    var nextSessionId: SessionIdentifier?
    var didCallStartSession: Bool = false
    var didCallEndSession: Bool = false
    var didCallUpdateSession: Bool = false

    private var startSessionCallback: ((EmbraceSession, Date) -> Void)?
    private var endSessionCallback: ((EmbraceSession, Date) -> Void)?

    private var updateSessionCallback: ((EmbraceSession, SessionState?, Bool?) -> Void)?

    var currentSession: EmbraceSession?

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession {
        if currentSession != nil {
            endSession()
        }

        var session = EmbraceSession(id: nextSessionId ?? .random, state: state, startTime: startTime)

        didCallStartSession = true
        currentSession = session

        startSessionCallback?(session, startTime)

        return session
    }

    func endSession() {
        guard let session = currentSession else {
            return
        }

        didCallEndSession = true
        currentSession = nil

        endSessionCallback?(session, Date())
    }

    func update(session: EmbraceIO.EmbraceSession, state: SessionState?, appTerminated: Bool?) {
        didCallUpdateSession = true

        updateSessionCallback?(session, state, appTerminated)
    }

    func onStartSession(_ callback: @escaping (EmbraceSession, Date) -> Void) {
        startSessionCallback = callback
    }

    func onEndSession(_ callback: @escaping (EmbraceSession, Date) -> Void) {
        endSessionCallback = callback
    }

    func onUpdateSession(_ callback: @escaping ((EmbraceSession, SessionState?, Bool?) -> Void)) {
        updateSessionCallback = callback
    }
}
