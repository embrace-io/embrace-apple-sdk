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

    private var _currentSession: EmbraceSession?
    var currentSession: EmbraceSession? {
        lock.locked { _currentSession }
    }

    private var _currentSessionSpan: Span?
    var currentSessionSpan: Span? {
        lock.locked { _currentSessionSpan }
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
            self?.update(heartbeat: Date())
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
        let session = lock.locked {

            // end current session first
            if _currentSession != nil {
                endSessionNoLock()
            }

            guard sdkStateProvider?.isEnabled == true else {
                return nil as EmbraceSession?
            }

            guard let storage = storage else {
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
            if isColdStart == false && state == .background && backgroundSessionsEnabled == false {
                return nil
            }
            // -

            // create session span
            let newId = EmbraceIdentifier.random
            let span = SessionSpanUtils.span(id: newId, startTime: startTime, state: state, coldStart: isColdStart)
            _currentSessionSpan = span

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
            _currentSession = session

            // start heartbeat
            heartbeat.start()

            firstSession = false
            _attachmentCount.store(0)

            return session
        }

        // post notification
        if let session {
            NotificationCenter.default.post(name: .embraceSessionDidStart, object: session)
        }

        return session
    }

    /// Ends the session session taking into account that the lock is held externally
    @discardableResult
    private func endSessionNoLock() -> Date {

        guard let session = _currentSession else {
            return Date()
        }

        // stop heartbeat
        heartbeat.stop()
        let now = Date()

        guard sdkStateProvider?.isEnabled == true else {
            deleteNoLock()
            return now
        }

        // If the session is a background session and background sessions
        // are disabled in the config, we drop the session!
        // +
        if session.coldStart == true && session.state == SessionState.background.rawValue
            && backgroundSessionsEnabled == false
        {
            deleteNoLock()
            return now
        }
        // -

        // auto terminate spans
        EmbraceOTel.processor?.autoTerminateSpans()

        // post public notification
        // This is behind a lock, this is a problem, so we move it to the main queue so it runs after this code.
        let mainQueueSession = _currentSession
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .embraceSessionWillEnd, object: mainQueueSession)
        }

        // end log batches
        logBatcher?.forceEndCurrentBatch(waitUntilFinished: true)

        // end span
        if let _currentSessionSpan {
            // Ending span for otel processors
            // Note: our exporter wont trigger an update on the stored span
            // to prevent race conditions.
            _currentSessionSpan.end(time: now)

            // Manually updating the span record synchronously.
            storage?.endSpan(
                id: _currentSessionSpan.context.spanId.hexString,
                traceId: _currentSessionSpan.context.traceId.hexString,
                endTime: now
            )
        }

        // update session end time and clean exit
        if session.id != nil {
            _currentSession = storage?.updateSession(session: session, endTime: now, cleanExit: true)
        }

        // post internal notification
        if session.state == SessionState.foreground.rawValue {
            Embrace.notificationCenter.post(name: .embraceForegroundSessionDidEnd, object: now)
        }

        // upload session
        uploadSessionNoLock()

        _currentSession = nil
        _currentSessionSpan = nil

        return now
    }

    /// Ends the session
    /// Will also set the session's `cleanExit` property to `true`
    /// - Returns: The `endTime` of the session
    @discardableResult
    func endSession() -> Date {
        return lock.locked {
            endSessionNoLock()
        }
    }

    func update(state: SessionState) {
        lock.locked {
            guard let session = _currentSession else {
                return
            }

            _currentSession = storage?.updateSession(session: session, state: state)

            if let span = _currentSessionSpan {
                SessionSpanUtils.setState(span: span, state: state)
                Embrace.client?.flush(span)
            }
        }
    }

    func update(appTerminated: Bool) {
        lock.locked {
            guard let session = _currentSession else {
                return
            }

            _currentSession = storage?.updateSession(session: session, appTerminated: appTerminated)

            if let span = _currentSessionSpan {
                SessionSpanUtils.setTerminated(span: span, terminated: appTerminated)
                Embrace.client?.flush(span)
            }
        }
    }

    func update(heartbeat: Date) {
        lock.locked {
            guard let session = _currentSession else {
                return
            }

            _currentSession = storage?.updateSession(session: session, lastHeartbeatTime: heartbeat)

            if let span = _currentSessionSpan {
                SessionSpanUtils.setHeartbeat(span: span, heartbeat: heartbeat)
                Embrace.client?.flush(span)
            }
        }
    }

    func uploadSessionNoLock() {
        guard let storage = storage,
            let upload = upload,
            let session = _currentSession
        else {
            return
        }

        queue.async { [weak self] in
            self?.uploader.uploadSession(session, storage: storage, upload: upload)
        }
    }

    func uploadSession() {
        lock.locked { uploadSessionNoLock() }
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
        lock.locked { deleteNoLock() }
    }

    private func deleteNoLock() {
        guard let session = _currentSession else {
            return
        }

        if let sessionId = session.id {
            storage?.deleteSession(id: sessionId)
        }

        _currentSession = nil
        _currentSessionSpan = nil
    }
}

// internal use
extension Notification.Name {
    static let embraceForegroundSessionDidEnd = Notification.Name("embrace.session.foreground.end")
}
