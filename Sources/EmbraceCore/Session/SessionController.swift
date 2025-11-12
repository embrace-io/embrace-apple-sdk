//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceStorageInternal
    import EmbraceUploadInternal
    import EmbraceOTelInternal
#endif

extension Notification.Name {
    public static let embraceSessionDidStart = Notification.Name("embrace.session.did_start")
    public static let embraceSessionWillEnd = Notification.Name("embrace.session.will_end")
}

/// The source of truth for sessions. Provides the CRUD functionality for a given EmbraceSession
/// This class should not be interacted with directly, but by using a ``SessionListener``.
///
/// This class will post notifications when:
///     Just after a session starts. See ``Notification.Name.embraceSessionDidStart``
///     Just before a session will end. See ``Notification.Name.embraceSessionWillEnd``
///

class SessionController: SessionControllable {

    private let _attachmentCount = EmbraceAtomic<Int32>(0)
    internal var attachmentCount: Int { Int(_attachmentCount.load()) }

    // Lock used for session boundaries. Will be shared at both start/end of session
    private let lock = UnfairLock()
    private weak var logBatcher: LogBatcher?
    weak var storage: EmbraceStorage?
    weak var upload: EmbraceUpload?
    private let uploader: SessionUploader
    weak var config: EmbraceConfig?
    weak var sdkStateProvider: EmbraceSDKStateProvider?

    private struct SessionInfo {
        var session: EmbraceSession? = nil
        var sessionSpan: Span? = nil
    }
    private let _session: EmbraceMutex<SessionInfo> = EmbraceMutex(SessionInfo())
    var currentSession: EmbraceSession? {
        _session.withLock { $0.session }
    }
    var currentSessionSpan: Span? {
        _session.withLock { $0.sessionSpan }
    }

    private var backgroundSessionsEnabled: Bool {
        return config?.isBackgroundSessionEnabled == true
    }

    let heartbeat: SessionHeartbeat
    let queue: DispatchableQueue
    var firstSession = true

    init(
        storage: EmbraceStorage,
        upload: EmbraceUpload?,
        uploader: SessionUploader = DefaultSessionUploader(),
        config: EmbraceConfig?,
        heartbeatInterval: TimeInterval = SessionHeartbeat.defaultInterval,
        queue: DispatchableQueue = .with(label: "com.embrace.session_controller_upload"),
        heartbeatQueue: DispatchQueue = DispatchQueue(label: "com.embrace.session_heartbeat")
    ) {
        self.storage = storage
        self.upload = upload
        self.uploader = uploader
        self.config = config

        self.heartbeat = SessionHeartbeat(queue: heartbeatQueue, interval: heartbeatInterval)
        self.queue = queue

        self.heartbeat.callback = { [weak self] in
            let span = EmbraceMetricKitSpan.begin(name: "heartbeat")
            self?.update(heartbeat: Date())
            span.end()
        }
    }

    deinit {
        heartbeat.stop()
    }

    func clear() {
        delete()
    }

    func setLogBatcher(_ batcher: LogBatcher) {
        self.logBatcher = batcher
    }

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession? {

        // we lock after end session to avoid a deadlock
        let inProgressSessionInfo = _session.safeValue
        let sessionInfo: (session: EmbraceSession?, span: Span?) = lock.locked {

            // end current session first
            if inProgressSessionInfo.session != nil {
                endSessionNoLock(inProgressSessionInfo.session, inProgressSessionInfo.sessionSpan)
            }

            guard sdkStateProvider?.isEnabled == true else {
                return (nil, nil)
            }

            guard let storage = storage else {
                return (nil, nil)
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
            if isColdStart == false && state == .background && backgroundSessionsEnabled == false {
                return (nil, nil)
            }
            // -

            // create session span
            let newId = EmbraceIdentifier.random
            let span = SessionSpanUtils.span(id: newId, startTime: startTime, state: state, coldStart: isColdStart)

            // create session record and save it
            let session = storage.addSession(
                id: newId,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: span.context.traceId.hexString,
                spanId: span.context.spanId.hexString,
                startTime: startTime,
                coldStart: isColdStart
            )

            // start heartbeat
            heartbeat.start()

            firstSession = false
            _attachmentCount.store(0)

            return (session: session, span: span)
        }

        _session.withLock {
            $0.session = sessionInfo.session
            $0.sessionSpan = sessionInfo.span
        }

        // post notification
        if let session = sessionInfo.session {
            NotificationCenter.default.post(name: .embraceSessionDidStart, object: session)
        }

        return sessionInfo.session
    }

    /// Ends the session session taking into account that the lock is held externally
    @discardableResult
    private func endSessionNoLock(_ inProgressSession: EmbraceSession?, _ inProgressSessionSpan: Span?) -> Date {

        guard let inProgressSession else {
            return Date()
        }

        // stop heartbeat
        heartbeat.stop()
        let now = Date()

        guard sdkStateProvider?.isEnabled == true else {
            deleteNoLock(inProgressSession)
            return now
        }

        // If the session is a background session and background sessions
        // are disabled in the config, we drop the session!
        // +
        if inProgressSession.coldStart == true && inProgressSession.state == SessionState.background.rawValue
            && backgroundSessionsEnabled == false
        {
            deleteNoLock(inProgressSession)
            return now
        }
        // -

        // auto terminate spans
        EmbraceOTel.processor?.autoTerminateSpans()

        // post public notification
        // This is behind a lock, this is a problem, so we move it to the main queue so it runs after this code.
        let mainQueueSession = inProgressSession
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .embraceSessionWillEnd, object: mainQueueSession)
        }

        // end log batches
        logBatcher?.forceEndCurrentBatch(waitUntilFinished: true)

        // end span
        if let inProgressSessionSpan {
            // Ending span for otel processors
            // Note: our exporter wont trigger an update on the stored span
            // to prevent race conditions.
            inProgressSessionSpan.end(time: now)

            // Manually updating the span record synchronously.
            storage?.endSpan(
                id: inProgressSessionSpan.context.spanId.hexString,
                traceId: inProgressSessionSpan.context.traceId.hexString,
                endTime: now
            )
        }

        // update session end time and clean exit
        var sessionToUpload: EmbraceSession? = inProgressSession
        if inProgressSession.id != nil {
            sessionToUpload = storage?.updateSession(session: inProgressSession, endTime: now, cleanExit: true)
        }

        // post internal notification
        if inProgressSession.state == SessionState.foreground.rawValue {
            Embrace.notificationCenter.post(name: .embraceForegroundSessionDidEnd, object: now)
        }

        // upload session
        uploadSessionNoLock(sessionToUpload)

        _session.withLock {
            $0.session = nil
            $0.sessionSpan = nil
        }

        return now
    }

    /// Ends the session
    /// Will also set the session's `cleanExit` property to `true`
    /// - Returns: The `endTime` of the session
    @discardableResult
    func endSession() -> Date {
        let sessionInfo = _session.safeValue
        return lock.locked {
            endSessionNoLock(sessionInfo.session, sessionInfo.sessionSpan)
        }
    }

    func update(state: SessionState) {
        let sessionInfo = _session.safeValue
        lock.locked {
            guard let session = sessionInfo.session else {
                return
            }

            let updatedSession = storage?.updateSession(session: session, state: state)
            _session.withLock {
                $0.session = updatedSession
            }

            if let span = sessionInfo.sessionSpan {
                SessionSpanUtils.setState(span: span, state: state)
                Embrace.client?.flush(span)
            }
        }
    }

    func update(appTerminated: Bool) {
        let sessionInfo = _session.safeValue
        lock.locked {
            guard let session = sessionInfo.session else {
                return
            }

            let updatedSession = storage?.updateSession(session: session, appTerminated: appTerminated)
            _session.withLock {
                $0.session = updatedSession
            }

            if let span = sessionInfo.sessionSpan {
                SessionSpanUtils.setTerminated(span: span, terminated: appTerminated)
                Embrace.client?.flush(span)
            }
        }
    }

    func update(heartbeat: Date) {
        let sessionInfo = _session.safeValue
        lock.locked {
            guard let session = sessionInfo.session else {
                return
            }

            let updatedSession = storage?.updateSession(session: session, lastHeartbeatTime: heartbeat)
            _session.withLock {
                $0.session = updatedSession
            }

            if let span = sessionInfo.sessionSpan {
                SessionSpanUtils.setHeartbeat(span: span, heartbeat: heartbeat)
                Embrace.client?.flush(span)
            }
        }
    }

    func uploadSessionNoLock(_ session: EmbraceSession?) {
        guard let storage = storage,
            let upload = upload,
            let session
        else {
            return
        }

        queue.async { [weak self] in
            self?.uploader.uploadSession(session, storage: storage, upload: upload)
        }
    }

    func uploadSession() {
        let session: EmbraceSession? = _session.withLock { $0.session }
        lock.locked { uploadSessionNoLock(session) }
    }

    func increaseAttachmentCount() {
        _attachmentCount += 1
    }
}

extension SessionController {
    private func save() {
        storage?.save()
    }

    private func delete() {
        let info = _session.safeValue
        lock.locked { deleteNoLock(info.session) }
    }

    private func deleteNoLock(_ session: EmbraceSession?) {
        guard let session else {
            return
        }

        if let sessionId = session.id {
            storage?.deleteSession(id: sessionId)
        }

        _session.withLock {
            $0.session = nil
            $0.sessionSpan = nil
        }
    }
}

// internal use
extension Notification.Name {
    static let embraceForegroundSessionDidEnd = Notification.Name("embrace.session.foreground.end")
}
