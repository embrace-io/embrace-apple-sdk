//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport

class MockSessionController: SessionControllable {

    // Properties for mocking
    var nextSessionId: SessionIdentifier?
    var didCallStartSession: Bool = false
    var didCallEndSession: Bool = false
    var didCallUpdateSession: Bool = false

    private var updateSessionCallback: ((SessionRecord?, SessionState?, Bool?) -> Void)?

    var currentSession: SessionRecord?

    @discardableResult
    func startSession(state: SessionState) -> SessionRecord? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> SessionRecord? {
        if currentSession != nil {
            endSession()
        }

        let session = SessionRecord(
            id: nextSessionId ?? .random,
            state: state,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: startTime
        )

        didCallStartSession = true
        currentSession = session

        return session
    }

    @discardableResult
    func endSession() -> Date {
        didCallEndSession = true
        currentSession = nil

        return Date()
    }

    func update(state: SessionState) {
        didCallUpdateSession = true

        updateSessionCallback?(currentSession, state, nil)
    }

    func update(appTerminated: Bool) {
        didCallUpdateSession = true

        updateSessionCallback?(currentSession, nil, appTerminated)
    }

    func onUpdateSession(_ callback: @escaping ((SessionRecord?, SessionState?, Bool?) -> Void)) {
        updateSessionCallback = callback
    }
}
