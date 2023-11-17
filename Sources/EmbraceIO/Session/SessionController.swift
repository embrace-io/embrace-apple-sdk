//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

extension Notification.Name {
    static let embraceSessionDidStart = Notification.Name("embrace.session.did_start")
    static let embraceSessionWillEnd = Notification.Name("embrace.session.will_start")
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

    private let saveLock = UnfairLock()

    weak var storage: EmbraceStorage?   // TODO: could this be an unowned var instead?

    internal var notificationCenter = NotificationCenter.default

    init(storage: EmbraceStorage) {
        self.storage = storage
    }

    func createSession(state: SessionState) -> EmbraceSession {
        return EmbraceSession(id: SessionIdentifier.random, state: state)
    }

    func start(session: EmbraceSession, at startAt: Date = Date()) {
        session.startAt = startAt
        session.coldStart = withinColdStartInterval(startAt: startAt)

        do {
            try save(session)
        } catch {
            // TODO: unable to start session
        }
        currentSession = session

        // post notification
        notificationCenter.post(name: .embraceSessionDidStart, object: session)
    }

    /// Ends the session
    /// Will set the session's `endAt` to the specific Date
    /// Will also set the session's `cleanExit` property to `true`
    func end(session: EmbraceSession, at endAt: Date = Date()) {
        notificationCenter.post(name: .embraceSessionWillEnd, object: session)

        session.endAt = endAt
        session.cleanExit = true
        do {
            try save(session)
        } catch {
            // TODO: unable to end session
        }

        currentSession = nil
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
    private func withinColdStartInterval(startAt: Date) -> Bool {
        guard let uptime = ProcessMetadata.uptime(since: startAt), uptime >= 0 else {
            return false
        }

        return uptime <= Self.allowedColdStartInterval
    }

    private func save(_ session: EmbraceSession) throws {
        guard let storage = storage else { return }
        guard let startAt = session.startAt else {
            return
        }

        try saveLock.locked {
            let record = SessionRecord(
                id: session.id.toString,
                state: session.state,
                processId: UUID(), // session.processId, TODO: FIXME, interface should use ProcessIdentifier
                startTime: startAt,
                endTime: session.endAt,
                coldStart: session.coldStart,
                cleanExit: session.cleanExit,
                appTerminated: session.appTerminated
            )

            try storage.upsertSession(record)
        }
    }
}
