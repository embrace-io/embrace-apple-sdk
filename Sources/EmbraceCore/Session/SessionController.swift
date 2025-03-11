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

/// This class will post notifications containing the `SessionIdentifier` when:
///     Just after a session starts. See ``Notification.Name.embraceSessionDidStart``
///     Just before a session will end. See ``Notification.Name.embraceSessionWillEnd``
///

class SessionController: SessionControllable {

    @ThreadSafe
    private(set) var currentSessionId: SessionIdentifier?

    @ThreadSafe
    private(set) var currentSessionState: SessionState?

    @ThreadSafe
    private(set) var currentSessionColdStart: Bool?

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
    let queue: DispatchQueue
    var firstSession = true

    init(
        storage: EmbraceStorage,
        upload: EmbraceUpload?,
        config: EmbraceConfig?,
        heartbeatInterval: TimeInterval = SessionHeartbeat.defaultInterval
    ) {
        self.storage = storage
        self.upload = upload
        self.config = config

        let heartbeatQueue = DispatchQueue(label: "com.embrace.session_heartbeat")
        self.heartbeat = SessionHeartbeat(queue: heartbeatQueue, interval: heartbeatInterval)
        self.queue = DispatchQueue(label: "com.embrace.session_controller_upload")

        self.heartbeat.callback = { [weak self] in
            self?.update(heartbeat: Date())
        }
    }

    deinit {
        heartbeat.stop()
    }

    func clear() {
        delete()
    }

    @discardableResult
    func startSession(state: SessionState) -> SessionIdentifier? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> SessionIdentifier? {
        // end current session first
        if currentSessionId != nil {
            endSession()
        }

        guard sdkStateProvider?.isEnabled == true else {
            return nil
        }

        guard let storage = storage else {
            return nil
        }

        // detect cold start
        let coldStart = firstSession

        // Don't start background session if the config is disabled.
        //
        // Note: There's an exception for the cold start session:
        // We start the session anyways and we drop it when it ends if
        // it's still considered a background session.
        // Due to how iOS works we can't know for sure the state when the
        // app starts, so we need to delay the logic!
        //
        // +
        if coldStart == false &&
           state == .background &&
           backgroundSessionsEnabled == false {
            return nil
        }
        // -

        // we lock after end session to avoid a deadlock

        return lock.locked {

            // create session span
            let newId = SessionIdentifier.random
            let span = SessionSpanUtils.span(id: newId, startTime: startTime, state: state, coldStart: coldStart)
            currentSessionSpan = span

            // create session record
            storage.addSession(
                id: newId,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: span.context.traceId.hexString,
                spanId: span.context.spanId.hexString,
                startTime: startTime,
                coldStart: coldStart
            )

            // start heartbeat
            heartbeat.start()

            // post notification
            NotificationCenter.default.post(name: .embraceSessionDidStart, object: newId)

            firstSession = false
            attachmentCount = 0

            currentSessionId = newId
            currentSessionColdStart = coldStart
            currentSessionState = state

            return newId
        }
    }

    /// Ends the session
    /// Will also set the session's `cleanExit` property to `true`
    /// - Returns: The `endTime` of the session
    @discardableResult
    func endSession() -> Date {
        guard let sessionId = currentSessionId else {
            return Date()
        }

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
            if currentSessionColdStart == true &&
               currentSessionState == SessionState.background &&
               backgroundSessionsEnabled == false {
                delete()
                return now
            }
            // -

            // auto terminate spans
            EmbraceOTel.processor?.autoTerminateSpans()

            // post public notification
            NotificationCenter.default.post(name: .embraceSessionWillEnd, object: currentSessionId)

            // set end time
            storage?.update(sessionId: sessionId, endTime: now, cleanExit: true)

            if let span = currentSessionSpan {
                span.end(time: now)
                SessionSpanUtils.setCleanExit(span: span, cleanExit: true)
                Embrace.client?.flush(span)
            }

            // post internal notification
            if currentSessionState == SessionState.foreground {
                Embrace.notificationCenter.post(name: .embraceForegroundSessionDidEnd, object: now)
            }

            // upload session
            uploadSession()

            currentSessionId = nil
            currentSessionState = nil
            currentSessionColdStart = nil
            currentSessionSpan = nil

            return now
        }
    }

    func update(state: SessionState) {
        guard let currentSessionId = currentSessionId else {
            return
        }

        currentSessionState = state

        storage?.update(sessionId: currentSessionId, state: state)

        if let span = currentSessionSpan {
            SessionSpanUtils.setState(span: span, state: state)
            Embrace.client?.flush(span)
        }
    }

    func update(appTerminated: Bool) {
        guard let currentSessionId = currentSessionId else {
            return
        }

        storage?.update(sessionId: currentSessionId, appTerminated: appTerminated)

        if let span = currentSessionSpan {
            SessionSpanUtils.setTerminated(span: span, terminated: appTerminated)
            Embrace.client?.flush(span)
        }
    }

    func update(heartbeat: Date) {
        guard let currentSessionId = currentSessionId else {
            return
        }

        storage?.update(sessionId: currentSessionId, lastHeartbeatTime: heartbeat)

        if let span = currentSessionSpan {
            SessionSpanUtils.setHeartbeat(span: span, heartbeat: heartbeat)
            Embrace.client?.flush(span)
        }
    }

    func uploadSession() {
        guard let storage = storage,
              let upload = upload,
              let sessionId = currentSessionId,
              let session = storage.fetchSession(id: sessionId) else {
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
        storage?.save()
    }

    private func delete() {
        guard let sessionId = currentSessionId else {
            return
        }

        if let session = storage?.fetchSession(id: sessionId) {
            storage?.delete(session)
        }

        currentSessionId = nil
        currentSessionSpan = nil
    }
}

// internal use
extension Notification.Name {
    static let embraceForegroundSessionDidEnd = Notification.Name("embrace.session.foreground.end")
}
