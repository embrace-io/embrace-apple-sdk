//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import Foundation
import TestSupport

@testable import EmbraceCore

class MockSessionController: SessionControllable {

    // Properties for mocking
    var nextSessionId: EmbraceIdentifier?
    var nextSessionColdStart: Bool = false
    var nextSessionAppTerminated: Bool = false

    var didCallStartSession: Bool = false
    var didCallEndSession: Bool = false
    var didCallUpdateSession: Bool = false

    private var updateSessionCallback: ((EmbraceSession?, SessionState?, Bool?) -> Void)?

    weak var storage: EmbraceStorage?
    var currentSession: EmbraceSession?

    func clear() {}

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession? {
        if currentSession != nil {
            endSession()
        }

        didCallStartSession = true

        var session: EmbraceSession?

        if let storage = storage {
            session = storage.addSession(
                id: nextSessionId ?? .random,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: startTime,
                coldStart: nextSessionColdStart,
                appTerminated: nextSessionAppTerminated
            )
        } else {
            session = MockSession(
                id: nextSessionId ?? .random,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: startTime,
                coldStart: nextSessionColdStart,
                appTerminated: nextSessionAppTerminated
            )
        }

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

    func onUpdateSession(_ callback: @escaping ((EmbraceSession?, SessionState?, Bool?) -> Void)) {
        updateSessionCallback = callback
    }

    var attachmentCount: Int = 0

    func increaseAttachmentCount() {
        attachmentCount += 1
    }
}
