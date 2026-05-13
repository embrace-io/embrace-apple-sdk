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

    /// Ordered log of every `startSession`/`endSession` call (and their timestamp) for tests
    /// that verify the bg-split sequence in `iOSSessionLifecycle.appDidBecomeActive`.
    enum Event: Equatable {
        case startSession(state: SessionState, startTime: Date)
        case endSession(at: Date)
    }
    var callLog: [Event] = []

    private var updateSessionCallback: ((EmbraceSession?, SessionState?, Bool?) -> Void)?

    weak var storage: EmbraceStorage?
    var currentSession: EmbraceSession?
    var currentSessionSpan: EmbraceSpan?
    weak var spanHandler: EmbraceSpanHandler?

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
        callLog.append(.startSession(state: state, startTime: startTime))

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
        callLog.append(.endSession(at: endTime))
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
