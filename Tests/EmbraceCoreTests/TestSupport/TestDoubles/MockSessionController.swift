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
    var currentSessionSpan: EmbraceSpan?
    var currentUserSession: EmbraceUserSession?
    weak var spanHandler: EmbraceSpanHandler?

    /// Forces the user session that the next started part will belong to.
    /// Leave it `nil` to keep the active user session (or create one if there isn't any).
    var nextUserSession: EmbraceUserSession?

    func clear() {}

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession? {
        return startSession(state: state, startTime: Date())
    }

    /// Ends the current user session, so the next part started begins a new one.
    /// Use it to simulate a user session expiring in between parts.
    @discardableResult
    func startNewUserSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession? {
        currentUserSession = nil
        nextUserSession = nil
        return startSession(state: state, startTime: startTime)
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession? {
        if currentSession != nil {
            endSession()
        }

        didCallStartSession = true

        // resolve the user session this part belongs to, mimicking `UserSessionController.attachPart`
        let userSession =
            nextUserSession
            ?? currentUserSession
            ?? ImmutableUserSession(
                id: .random,
                startTime: startTime,
                maxDuration: UserSessionSemantics.defaultMaxDurationSeconds,
                inactivityTimeout: UserSessionSemantics.defaultInactivityTimeoutSeconds,
                partIndex: 1,
                isBackgroundOnly: state == .background
            )
        currentUserSession = userSession

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
                appTerminated: nextSessionAppTerminated,
                userSessionId: userSession.id,
                userSessionStartTime: userSession.startTime,
                userSessionMaxDuration: userSession.maxDuration,
                userSessionInactivityTimeout: userSession.inactivityTimeout,
                userSessionPartIndex: userSession.partIndex
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
                appTerminated: nextSessionAppTerminated,
                userSessionId: userSession.id,
                userSessionStartTime: userSession.startTime,
                userSessionMaxDuration: userSession.maxDuration,
                userSessionInactivityTimeout: userSession.inactivityTimeout,
                userSessionPartIndex: userSession.partIndex
            )
        }

        currentSession = session

        currentSessionSpan = InternalEmbraceSpan(
            context: EmbraceSpanContext(
                spanId: TestConstants.spanId,
                traceId: TestConstants.traceId
            ),
            name: "emb-session",
            type: .session,
            status: .ok,
            startTime: startTime,
            attributes: [
                "session.id": session!.id.stringValue,
                "emb.state": state.rawValue,
                "emb.cold_start": String(nextSessionColdStart),
                "emb.terminated": String(nextSessionAppTerminated)
            ],
            sessionId: session!.id,
            processId: ProcessIdentifier.current,
            handler: spanHandler
        )
        if let storage {
            storage.upsertSpan(currentSessionSpan!)
        }

        return session
    }

    @discardableResult
    func endSession() -> Date {
        return endSession(at: Date())
    }

    @discardableResult
    func endSession(at endTime: Date) -> Date {
        didCallEndSession = true
        currentSession = nil

        if let span = currentSessionSpan {
            span.end(endTime: endTime)
            storage?.upsertSpan(span)
        }
        currentSessionSpan = nil

        return endTime
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
