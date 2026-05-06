//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceStorageInternal
    import EmbraceUploadInternal
#endif

extension Notification.Name {
    /// Posted just after a session part starts. The `object` is the newly-created `EmbraceSession`
    /// (the part). For user-session lifecycle, listen to `embraceUserSessionDidStart` instead.
    public static let embraceSessionPartDidStart = Notification.Name("embrace.session.part.did_start")

    /// Posted just before a session part ends. The `object` is the `EmbraceSession` (the part)
    /// that is about to end. For user-session lifecycle, listen to `embraceUserSessionDidEnd`.
    public static let embraceSessionPartWillEnd = Notification.Name("embrace.session.part.will_end")
}

/// The source of truth for session parts. A "part" is one contiguous foreground/background
/// interval; a user session groups one or more parts and is owned by `UserSessionController`.
///
/// This class should not be interacted with directly, but by using a ``SessionListener``.
///
/// This class will post notifications when:
///     Just after a part starts. See ``Notification.Name.embraceSessionPartDidStart``
///     Just before a part will end. See ``Notification.Name.embraceSessionPartWillEnd``
///

class SessionController: SessionControllable {

    static let sessionNumberKey = "emb.session.upload_index"

    private let _attachmentCount = EmbraceAtomic<Int32>(0)
    internal var attachmentCount: Int { Int(_attachmentCount.load()) }

    // Lock used for session boundaries. Will be shared at both start/end of session
    private let lock = UnfairLock()
    weak var storage: EmbraceStorage?
    weak var upload: EmbraceUpload?
    private let uploader: SessionUploader
    weak var config: EmbraceConfig?
    weak var sdkStateProvider: EmbraceSDKStateProvider?
    weak var otel: InternalOTelSignalsHandler?
    weak var userSessionController: UserSessionController?

    private struct SessionInfo {
        var session: EmbraceSession? = nil
        var sessionSpan: EmbraceSpan? = nil
    }
    private let _session: EmbraceMutex<SessionInfo> = EmbraceMutex(SessionInfo())
    var currentSession: EmbraceSession? {
        _session.withLock { $0.session }
    }
    var currentSessionSpan: EmbraceSpan? {
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

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession? {
        return startSession(state: state, startTime: Date())
    }

    @discardableResult
    func startSession(state: SessionState, startTime: Date = Date()) -> EmbraceSession? {
        // we lock after end session to avoid a deadlock
        let inProgressSessionInfo = _session.safeValue
        let sessionInfo: (session: EmbraceSession?, span: EmbraceSpan?) = lock.locked {

            // end current session first
            if inProgressSessionInfo.session != nil {
                endSessionNoLock(inProgressSessionInfo.session, inProgressSessionInfo.sessionSpan)
            }

            guard sdkStateProvider?.isEnabled == true else {
                return (nil, nil)
            }

            guard let storage = storage,
                let otel = otel
            else {
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
            guard
                let span = SessionSpanUtils.span(
                    otel: otel,
                    id: newId,
                    startTime: startTime,
                    state: state,
                    coldStart: isColdStart
                )
            else {
                return (nil, nil)
            }

            // Resolve which user session this new part belongs to. The user-session controller
            // decides whether to reuse the active user session or start a new one, owns the
            // `emb.session.upload_index` increment when a new user session is created, and
            // returns the snapshot we stamp onto the new part record.
            let userSession = userSessionController?.attachPart(state: state, startTime: startTime)

            let session = storage.addSession(
                id: newId,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: span.context.traceId,
                spanId: span.context.spanId,
                startTime: startTime,
                coldStart: isColdStart,
                sessionNumber: userSession?.userSessionNumber ?? 0,
                userSessionId: userSession?.id,
                userSessionStartTime: userSession?.startTime,
                userSessionMaxDuration: userSession?.maxDuration,
                userSessionInactivityTimeout: userSession?.inactivityTimeout,
                userSessionLastForegroundEnd: userSession?.lastForegroundPartEnd,
                userSessionPartIndex: userSession?.partIndex ?? 0
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
            NotificationCenter.default.post(name: .embraceSessionPartDidStart, object: session)
        }

        return sessionInfo.session
    }

    /// Ends the session session taking into account that the lock is held externally
    @discardableResult
    private func endSessionNoLock(_ inProgressSession: EmbraceSession?, _ inProgressSessionSpan: EmbraceSpan?) -> Date {

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
        if inProgressSession.coldStart == true && inProgressSession.state == SessionState.background && backgroundSessionsEnabled == false {
            deleteNoLock(inProgressSession)
            return now
        }
        // -

        // auto terminate spans
        otel?.autoTerminateSpans()

        // post public notification
        // This is behind a lock, this is a problem, so we move it to the main queue so it runs after this code.
        let mainQueueSession = inProgressSession
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .embraceSessionPartWillEnd, object: mainQueueSession)
        }

        // end span
        if let inProgressSessionSpan {
            // Ending span for otel processors
            // Note: our exporter wont trigger an update on the stored span
            // to prevent race conditions.
            inProgressSessionSpan.end(endTime: now)

            // TODO: Check if needed
            // Manually updating the span record synchronously.
            // storage?.endSpan(
            //     id: inProgressSessionSpan.context.spanId.hexString,
            //     traceId: inProgressSessionSpan.context.traceId.hexString,
            //     endTime: now
            // )
        }

        // update session end time and clean exit. For foreground parts, also record the
        // foreground-end timestamp on the part record AND on the in-memory user-session
        // snapshot so the next `attachPart` can compute the inactivity cutoff.
        let isForeground = inProgressSession.state == SessionState.foreground
        let sessionToUpload: EmbraceSession? = storage?.updateSession(
            session: inProgressSession,
            endTime: now,
            cleanExit: true,
            userSessionLastForegroundEnd: isForeground ? now : nil
        )

        if isForeground {
            userSessionController?.markForegroundPartEnded(at: now)
        }

        // post internal notification
        if isForeground {
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

    /// Stamps the given termination reason on the most recently closed part record.
    ///
    /// Called by `UserSessionController` when ending a user session — the part being stamped
    /// is, by construction, the last part of that user session.
    ///
    /// - Note: Currently a no-op. The storage write (looking up the just-closed part record
    ///   and calling `storage?.updateSession(..., userSessionTerminationReason: reason)`) lands
    ///   alongside the other end-reason wiring once the heartbeat-driven max-duration detector
    ///   and the manual-end API exist.
    func backfillTerminationReasonOnLatestPart(_ reason: TerminationReason) {
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

        storage?.deleteSession(id: session.id)

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
