//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceOTelInternal
import OpenTelemetryApi

public extension Notification.Name {
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

    @ThreadSafe
    private(set) var attachmentCount: Int = 0

    // Lock used for session boundaries. Will be shared at both start/end of session
    private let lock = UnfairLock()

    weak var storage: EmbraceStorage?
    weak var upload: EmbraceUpload?
    weak var config: EmbraceConfig?
    weak var sdkStateProvider: EmbraceSDKStateProvider?

    private var backgroundSessionsEnabled: Bool {
        return config?.isBackgroundSessionEnabled == true
    }

    let heartbeat: SessionHeartbeat
    let queue: DispatchableQueue
    var firstSession = true

    init(
        storage: EmbraceStorage,
        upload: EmbraceUpload?,
        config: EmbraceConfig?,
        heartbeatInterval: TimeInterval = SessionHeartbeat.defaultInterval,
        queue: DispatchableQueue = .with(label: "com.embrace.session_controller_upload"),
        heartbeatQueue: DispatchQueue = DispatchQueue(label: "com.embrace.session_heartbeat")
    ) {
        self.storage = storage
        self.upload = upload
        self.config = config

        self.heartbeat = SessionHeartbeat(queue: heartbeatQueue, interval: heartbeatInterval)
        self.queue = queue

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

    func clear() {
        delete()
    }

    @discardableResult
    func startSession(state: SessionState) -> SessionRecord? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> SessionRecord? {
        // end current session first
        if currentSession != nil {
            endSession()
        }

        guard sdkStateProvider?.isEnabled == true else {
            return nil
        }

        // detect cold start
        let isColdStart = firstSession

        // Don't start background session if the config is disabled.
        //
        // Note: There's an exception for the cold start session:
        // We start the session anyways and we drop it when it ends if
        // it's still considered a background session.
        // Due to how iOS works we can't know for sure the state when the
        // app starts, so we need to delay the logic!
        //
        // +
        if isColdStart == false &&
           state == .background &&
           backgroundSessionsEnabled == false {
            return nil
        }
        // -

        // we lock after end session to avoid a deadlock

        return lock.locked {

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
            NotificationCenter.default.post(name: .embraceSessionDidStart, object: session)

            firstSession = false
            attachmentCount = 0

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
            let now = Date()

            guard sdkStateProvider?.isEnabled == true else {
                delete()
                return now
            }

            // If the session is a background session and background sessions
            // are disabled in the config, we drop the session!
            // +
            if currentSession?.coldStart == true &&
               currentSession?.state == SessionState.background.rawValue &&
               backgroundSessionsEnabled == false {
                delete()
                return now
            }
            // -

            // auto terminate spans
            EmbraceOTel.processor?.autoTerminateSpans()

            // post public notification
            NotificationCenter.default.post(name: .embraceSessionWillEnd, object: currentSession)

            currentSessionSpan?.end(time: now)
            SessionSpanUtils.setCleanExit(span: currentSessionSpan, cleanExit: true)

            currentSession?.endTime = now
            currentSession?.cleanExit = true

            // post internal notification
            if currentSession?.state == SessionState.foreground.rawValue {
                Embrace.notificationCenter.post(name: .embraceForegroundSessionDidEnd, object: now)
            }

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

    func increaseAttachmentCount() {
        attachmentCount += 1
    }
}

extension SessionController {
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

    private func delete() {
        guard let storage = storage,
              let session = currentSession else {
            return
        }

        do {
            try storage.delete(record: session)
        } catch {
            Embrace.logger.warning("Error trying to delete session:\n\(error.localizedDescription)")
        }

        currentSession = nil
        currentSessionSpan = nil
    }
}

// internal use
extension Notification.Name {
    static let embraceForegroundSessionDidEnd = Notification.Name("embrace.session.foreground.end")
}
