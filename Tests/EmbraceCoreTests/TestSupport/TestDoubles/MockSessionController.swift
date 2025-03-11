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

    private var updateSessionCallback: ((SessionIdentifier?, SessionState?, Bool?) -> Void)?

    weak var storage: EmbraceStorage?

    var currentSessionId: SessionIdentifier?
    var currentSessionState: SessionState?
    var currentSessionColdStart: Bool?

    func clear() { }

    @discardableResult
    func startSession(state: SessionState) -> SessionIdentifier? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> SessionIdentifier? {
        if currentSessionId != nil {
            endSession()
        }

        didCallStartSession = true

        let newId = nextSessionId ?? .random

        if let storage = storage {
            storage.addSession(
                id: newId,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: startTime
            )
        }

        currentSessionId = newId
        currentSessionState = state
        currentSessionColdStart = false

        return newId
    }

    @discardableResult
    func endSession() -> Date {
        didCallEndSession = true
        currentSessionId = nil
        currentSessionState = nil
        currentSessionColdStart = nil

        return Date()
    }

    func update(state: SessionState) {
        didCallUpdateSession = true

        updateSessionCallback?(currentSessionId, state, nil)
    }

    func update(appTerminated: Bool) {
        didCallUpdateSession = true

        updateSessionCallback?(currentSessionId, nil, appTerminated)
    }

    func onUpdateSession(_ callback: @escaping ((SessionIdentifier?, SessionState?, Bool?) -> Void)) {
        updateSessionCallback = callback
    }

    var attachmentCount: Int = 0

    func increaseAttachmentCount() {
        attachmentCount += 1
    }
}
