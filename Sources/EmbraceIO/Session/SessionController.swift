//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage
import EmbraceOTel

extension Notification.Name {
    static let embraceSessionDidStart = Notification.Name("embrace.session.did_start")
    static let embraceSessionWillEnd = Notification.Name("embrace.session.will_end")
}

/// The source of truth for sessions. Provides the CRUD functionality for a given EmbraceSession
/// This class should not be interacted with directly, but by using a ``SessionListener``.
///
/// This class will post notifications when:
///     Just after a session starts. See ``Notification.Name.embraceSessionDidStart``
///     Just before a session will end. See ``Notification.Name.embraceSessionWillEnd``
///

class SessionController: SessionControllable {

    @ThreadSafe
    private(set) var currentSession: EmbraceSession?

    @ThreadSafe
    private(set) var currentSessionSpan: Span?

    private let saveLock = UnfairLock()

    let heartbeat: SessionHeartbeat
    weak var storage: EmbraceStorage?

    internal var notificationCenter = NotificationCenter.default

    init(storage: EmbraceStorage, heartbeatInterval: TimeInterval = SessionHeartbeat.defaultInterval) {
        self.storage = storage

        let heartbeatQueue = DispatchQueue(label: "com.embrace.session_heartbeat")
        self.heartbeat = SessionHeartbeat(queue: heartbeatQueue, interval: heartbeatInterval)

        self.heartbeat.callback = { [weak self] in
            if let session = self?.currentSession {
                session.lastHeartbeatTime = Date()
                do {
                    try self?.save(session)
                } catch {
                    ConsoleLog.warning("Error trying to update session heartbeat!:\n\(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        heartbeat.stop()
    }

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession {
        // end current session first
        if currentSession != nil {
            endSession()
        }

        // create new session
        let session = EmbraceSession(id: SessionIdentifier.random, state: state, startTime: startTime)
        session.coldStart = withinColdStartInterval(startTime: startTime)
        currentSession = session

        do {
            try save(session)
        } catch {
            // TODO: unable to start session
        }

        // create session span
        currentSessionSpan = createSpan(sessionId: session.id, startTime: startTime)

        // start heartbeat
        heartbeat.start()

        // post notification
        notificationCenter.post(name: .embraceSessionDidStart, object: session)

        return session
    }

    /// Ends the session
    /// Will also set the session's `cleanExit` property to `true`
    func endSession() {
        guard let session = currentSession else {
            return
        }

        // stop heartbeat
        heartbeat.stop()

        // post notification
        notificationCenter.post(name: .embraceSessionWillEnd, object: session)

        let now = Date()
        currentSessionSpan?.end(time: now)
        session.endTime = now
        session.cleanExit = true
        do {
            try save(session)
        } catch {
            // TODO: unable to end session
        }

        currentSession = nil
        currentSessionSpan = nil
    }

    func update(session: EmbraceSession, state: SessionState? = nil, appTerminated: Bool? = nil) {
        if let state = state {
            session.state = state
        }

        if let appTerminated = appTerminated {
            session.appTerminated = appTerminated
        }

        // save session record
        do {
            try save(session)
        } catch {
            // TODO: unable to update session
        }
    }
}

extension SessionController {
    static let allowedColdStartInterval: TimeInterval = 5.0

    /// - Returns: `true` if ``ProcessMetadata.uptime`` is less than or equal to the allowed cold start interval. See ``iOSAppListener.minimumColdStartInterval``
    private func withinColdStartInterval(startTime: Date) -> Bool {
        guard let uptime = ProcessMetadata.uptime(since: startTime), uptime >= 0 else {
            return false
        }

        return uptime <= Self.allowedColdStartInterval
    }

    private func save(_ session: EmbraceSession) throws {
        guard let storage = storage else { return }

        try saveLock.locked {
            let record = SessionRecord(
                id: session.id.toString,
                state: session.state,
                processId: session.processId,
                startTime: session.startTime,
                endTime: session.endTime,
                lastHeartbeatTime: session.lastHeartbeatTime,
                coldStart: session.coldStart,
                cleanExit: session.cleanExit,
                appTerminated: session.appTerminated
            )

            try storage.upsertSession(record)
        }
    }
}

extension SessionController {

    func createSpan(sessionId: SessionIdentifier, startTime: Date) -> Span {
        EmbraceOTel().buildSpan(name: "emb-session", type: .session)
            .setStartTime(time: startTime)
            .setAttribute(key: "emb.session_id", value: sessionId.toString)
            .startSpan()
    }
}
