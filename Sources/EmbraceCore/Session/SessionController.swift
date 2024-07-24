//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceOTelInternal

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
    private(set) var currentSession: SessionRecord?

    @ThreadSafe
    private(set) var currentSessionSpan: Span?

    // Lock used for session boundaries. Will be shared at both start/end of session
    private let lock = UnfairLock()

    weak var storage: EmbraceStorage?
    weak var upload: EmbraceUpload?
    let heartbeat: SessionHeartbeat
    let queue: DispatchQueue

    internal var notificationCenter = NotificationCenter.default

    init(
        storage: EmbraceStorage,
        upload: EmbraceUpload?,
        heartbeatInterval: TimeInterval = SessionHeartbeat.defaultInterval
    ) {
        self.storage = storage
        self.upload = upload

        let heartbeatQueue = DispatchQueue(label: "com.embrace.session_heartbeat")
        self.heartbeat = SessionHeartbeat(queue: heartbeatQueue, interval: heartbeatInterval)
        self.queue = DispatchQueue(label: "com.embrace.session_controller_upload")

        self.heartbeat.callback = { [weak self] in
            let heartbeat = Date()
            self?.currentSession?.lastHeartbeatTime = heartbeat
            SessionSpanUtils.setHeartbeat(span: self?.currentSessionSpan, heartbeat: heartbeat)
            self?.save()
        }
    }

    deinit {
        heartbeat.stop()
    }

    @discardableResult
    func startSession(state: SessionState) -> SessionRecord {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> SessionRecord {
        // end current session first
        if currentSession != nil {
            endSession()
        }

        // we lock after end session to avoid a deadlock

        return lock.locked {

            // detect cold start
            let isColdStart = withinColdStartInterval(startTime: startTime)

            // create session span
            let newId = SessionIdentifier.random
            let span = SessionSpanUtils.span(id: newId, startTime: startTime, state: state, coldStart: isColdStart)
            currentSessionSpan = span

            // create session record
            var session = SessionRecord(
                id: newId,
                state: state,
                processId: ProcessIdentifier.current,
                traceId: span.context.traceId.hexString,
                spanId: span.context.spanId.hexString,
                startTime: startTime
            )
            session.coldStart = isColdStart
            currentSession = session

            // save session record
            save()

            // start heartbeat
            heartbeat.start()

            // post notification
            notificationCenter.post(name: .embraceSessionDidStart, object: session)

            return session
        }
    }

    /// Ends the session
    /// Will also set the session's `cleanExit` property to `true`
    /// - Returns: The `endTime` of the session
    @discardableResult
    func endSession() -> Date {
        return lock.locked {
            // stop heartbeat
            heartbeat.stop()

            // post notification
            notificationCenter.post(name: .embraceSessionWillEnd, object: currentSession)

            let now = Date()
            currentSessionSpan?.end(time: now)
            SessionSpanUtils.setCleanExit(span: currentSessionSpan, cleanExit: true)

            currentSession?.endTime = now
            currentSession?.cleanExit = true

            // save session record
            save()

            // upload session
            uploadSession()

            currentSession = nil
            currentSessionSpan = nil

            return now
        }
    }

    func update(state: SessionState) {
        SessionSpanUtils.setState(span: currentSessionSpan, state: state)
        currentSession?.state = state.rawValue
        save()
    }

    func update(appTerminated: Bool) {
        SessionSpanUtils.setTerminated(span: currentSessionSpan, terminated: appTerminated)
        currentSession?.appTerminated = appTerminated
        save()
    }

    func uploadSession() {
        guard let storage = storage,
              let upload = upload,
              let session = currentSession else {
            return
        }

        queue.async {
            UnsentDataHandler.sendSession(session, storage: storage, upload: upload)
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

    private func save() {
        guard let storage = storage,
              let session = currentSession else {
            return
        }

        do {
            try storage.upsertSession(session)
        } catch {
            Embrace.logger.warning("Error trying to update session:\n\(error.localizedDescription)")
        }
    }
}
