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

/// The source of truth for session parts. A "part" is one contiguous foreground or background
/// interval; a user session groups one or more parts and is owned by `UserSessionController`.
///
/// This class should not be interacted with directly, but by using a ``SessionListener``.
///
/// This class will post notifications when:
///     Just after a part starts. See ``Notification.Name.embraceSessionPartDidStart``
///     Just before a part will end. See ``Notification.Name.embraceSessionPartWillEnd``
///

class SessionController: SessionControllable {

    static let sessionPartNumberKey = "emb.session_part_number"

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
            let now = Date()
            self?.update(heartbeat: now)
            self?.checkUserSessionMaxDurationExpiry(now: now)
            span.end()
        }
    }

    /// Triggered each heartbeat tick. If the active user session has crossed its max-duration
    /// cutoff *while the current part is in the foreground*, schedules a part-roll on the upload
    /// coordination queue so the work doesn't stall the heartbeat thread. The roll closes the current
    /// part, ends the user session with `.maxDurationReached`, and starts a new part with the same
    /// state.
    ///
    /// Max-duration is only enforced at runtime for a foreground part. A backgrounded session is
    /// never expired by the timer — its expiry is resolved lazily at the next foreground transition or
    /// cold start (so a background-only session may legitimately outlive its max). This also prevents
    /// slicing a background-only session at its own max.
    ///
    /// The expiry decision runs INSIDE the dispatched block — not before — so that two ticks
    /// queued back-to-back can't both roll. The second block sees the state left by the first
    /// (the freshly-rotated user session has a far-future `maxEnd`) and bails.
    func checkUserSessionMaxDurationExpiry(now: Date) {
        queue.async { [weak self] in
            guard let self = self,
                let userSession = self.userSessionController?.currentUserSession,
                now >= userSession.maxEnd,
                let currentSession = self._session.safeValue.session,
                currentSession.state == .foreground
            else {
                return
            }
            self.rollPartForUserSessionExpiry(reason: .maxDurationReached, at: now)
        }
    }

    /// If a foreground part is about to start after a background part whose user session
    /// crossed its `maxDuration` or `inactivityTimeout` cutoff, slice the bg part at the
    /// cutoff and produce three user sessions:
    ///   - the bg part `[bg.start, cutoff]` stays in the original user session `S1`;
    ///   - a synthetic bg part `[cutoff, now]` holds the tail in a brand-new user session `S2`;
    ///   - `S2` is then ended so the foreground part the caller is about to create begins a
    ///     fresh user session `S3` rather than joining `S2`.
    ///
    /// Returns `true` when the split was applied — the caller must skip its own "end previous
    /// part" step because the prev part is already closed.
    @discardableResult
    private func applyBackgroundSplitIfNeeded(
        prev: EmbraceSession?,
        newState: SessionState,
        now: Date
    ) -> Bool {
        guard newState == .foreground,
            let prev = prev,
            prev.state == .background,
            let userSession = userSessionController?.currentUserSession,
            // Only a foreground-origin session is split at its cutoff. A background-only session is
            // never sliced at its own max; foregrounding it ends it whole,
            // which `UserSessionController.attachPart` handles after this returns `false`.
            !userSession.isBackgroundOnly
        else {
            return false
        }

        let inactivityCutoff = userSession.lastForegroundPartEnd?.addingTimeInterval(userSession.inactivityTimeout)
        guard let cutoff = [userSession.maxEnd, inactivityCutoff].compactMap({ $0 }).min(),
            now >= cutoff,
            cutoff > prev.startTime
        else {
            return false
        }

        endSession(at: cutoff)
        startSession(state: .background, startTime: cutoff)
        endSession(at: now)

        // End the synthetic bg part's user session so the foreground part the caller starts
        // next does not join it — it must open its own user session.
        userSessionController?.endActiveUserSession(reason: .backgroundUserSessionForegrounded, at: now)
        return true
    }

    /// Closes the current part at `now`, ends the user session with the given reason, then
    /// starts a new part with the same `SessionState`. Used by the heartbeat-driven max-duration
    /// detector and the manual `endUserSession()` API. The order — end-part → end-user-session
    /// → start-part — guarantees that `attachPart` for the new part sees no active user session.
    func rollPartForUserSessionExpiry(reason: TerminationReason, at now: Date) {
        let info = _session.safeValue
        let currentState = info.session?.state ?? .unknown
        guard info.session != nil else { return }

        endSession(at: now)
        userSessionController?.endActiveUserSession(reason: reason, at: now)
        startSession(state: currentState, startTime: now)
    }

    /// Persists the cold-start that `UserSessionController.bootstrap` decided on: closes the
    /// prior foreground-origin session's final background part at `cutoff` (stamping `s1Reason`), and
    /// writes a closed background-only tail part `[cutoff, tailEnd]` belonging to the new user session
    /// `s2`. The caller sets the in-memory `s2` snapshot; this method only writes records, so both the
    /// closed foreground-origin session and the new background-only tail upload as normal parts.
    ///
    /// Runs at SDK start before `sessionLifecycle.startSession()` and before unsent data is uploaded,
    /// so the prior record is still present and the OTel handler is ready to mint the tail span. This
    /// is the cold-start equivalent of `applyBackgroundSplitIfNeeded`'s warm split.
    func writeColdStartBackgroundSplit(
        prior: EmbraceSession,
        cutoff: Date,
        tailEnd: Date,
        s1Reason: TerminationReason,
        s2: EmbraceUserSession
    ) {
        guard let storage = storage, let otel = otel else {
            return
        }

        // Close the foreground-origin session's final (background) part at the cutoff.
        storage.updateSession(session: prior, endTime: cutoff, userSessionTerminationReason: s1Reason)

        // Materialize the background-only tail part [cutoff, tailEnd] under the new user session.
        let newId = EmbraceIdentifier.random
        guard
            let span = SessionSpanUtils.span(
                otel: otel,
                id: newId,
                startTime: cutoff,
                state: .background,
                coldStart: false
            )
        else {
            return
        }
        span.end(endTime: tailEnd)

        let sessionPartNumber = storage.incrementCountForPermanentResource(key: SessionController.sessionPartNumberKey)

        storage.addSession(
            id: newId,
            processId: prior.processId,
            state: .background,
            traceId: span.context.traceId,
            spanId: span.context.spanId,
            startTime: cutoff,
            endTime: tailEnd,
            lastHeartbeatTime: tailEnd,
            crashReportId: prior.crashReportId,
            coldStart: false,
            cleanExit: prior.cleanExit,
            appTerminated: prior.appTerminated,
            sessionNumber: sessionPartNumber,
            userSessionId: s2.id,
            userSessionStartTime: s2.startTime,
            userSessionMaxDuration: s2.maxDuration,
            userSessionInactivityTimeout: s2.inactivityTimeout,
            userSessionLastForegroundEnd: nil,
            userSessionPartIndex: 1
        )
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

        // Background-to-foreground transition that crosses a user-session cutoff during the
        // bg interval: slice the bg part at the cutoff and insert a synthetic bg part
        // [cutoff, now] so the tail is attributed to a fresh user session rather than dragging
        // the old one into the foreground. The synthetic part runs through `attachPart`, which
        // expires the old user session and creates a new one before the actual fg part starts.
        let bgSplitFired = applyBackgroundSplitIfNeeded(
            prev: inProgressSessionInfo.session,
            newState: state,
            now: startTime
        )

        let sessionInfo: (session: EmbraceSession?, span: EmbraceSpan?) = lock.locked {

            // end current session first (skipped if bg-split already closed the prev part).
            // The previous part ends exactly at the new part's `startTime` — parts are
            // contiguous, and using a separate `Date()` here would stamp a
            // `lastForegroundPartEnd` a few ms *after* `startTime`, which `attachPart` would
            // then misread as the clock moving backwards (a false `.clockAnomaly`).
            if !bgSplitFired, inProgressSessionInfo.session != nil {
                endSessionNoLock(inProgressSessionInfo.session, inProgressSessionInfo.sessionSpan, endTime: startTime)
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
            // decides whether to reuse the active user session or start a new one, and returns
            // the snapshot we stamp onto the new part record.
            let userSession = userSessionController?.attachPart(state: state, startTime: startTime)

            // Permanent per-part counter — bumped on every new part record and stamped onto
            // the part's `sessionNumber` column.
            let sessionPartNumber = storage.incrementCountForPermanentResource(
                key: SessionController.sessionPartNumberKey
            )

            let session = storage.addSession(
                id: newId,
                processId: ProcessIdentifier.current,
                state: state,
                traceId: span.context.traceId,
                spanId: span.context.spanId,
                startTime: startTime,
                coldStart: isColdStart,
                sessionNumber: sessionPartNumber,
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
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .embraceSessionPartDidStart, object: session)
            }
        }

        return sessionInfo.session
    }

    /// Ends the session session taking into account that the lock is held externally
    @discardableResult
    private func endSessionNoLock(
        _ inProgressSession: EmbraceSession?,
        _ inProgressSessionSpan: EmbraceSpan?,
        endTime: Date? = nil
    ) -> Date {

        guard let inProgressSession else {
            return endTime ?? Date()
        }

        // stop heartbeat
        heartbeat.stop()
        let now = endTime ?? Date()

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

        // update session part end time and clean exit. For foreground parts, also record the
        // foreground-end timestamp on the part record AND on the in-memory user-session
        // snapshot so the next `attachPart` can compute the inactivity cutoff.
        let isForeground = inProgressSession.state == SessionState.foreground
        let sessionToUpload: EmbraceSession? = storage?.updateSession(
            session: inProgressSession,
            endTime: now,
            cleanExit: true,
            // nil will not overwrite previously-set userSessionLastForegroundEnd value
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

    /// Ends the session using the supplied `endTime` rather than `Date()`. Used when splitting
    /// a background part along a user-session cutoff: the part record must close exactly at the
    /// cutoff timestamp so the subsequent (synthetic) bg part can begin from the same instant.
    @discardableResult
    func endSession(at endTime: Date) -> Date {
        let sessionInfo = _session.safeValue
        return lock.locked {
            endSessionNoLock(sessionInfo.session, sessionInfo.sessionSpan, endTime: endTime)
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
    /// is, by construction, the last part of that user session. Looks up the latest persisted
    /// part record via storage so the call works after `endSession` has already cleared the
    /// in-memory snapshot.
    ///
    /// Idempotent: if the latest part already has a `userSessionTerminationReason`, the call
    /// is a no-op. This protects the bootstrap-driven expiry path from overwriting a reason
    /// the prior process recorded (e.g. `.manual` from a manual end that the process executed
    /// just before dying), and preserves the precedence rule that the first-set reason wins.
    ///
    /// **Lock contract:** this method MUST NOT acquire `SessionController.lock`. It is reached
    /// from `UserSessionController.internalEndUserSession`, which itself runs under the
    /// user-session controller's `_state` mutex (via `attachPart` and `endActiveUserSession`).
    /// Holding `_state` while acquiring `lock` would create two failure modes:
    ///   - When the caller is `SessionController.startSession`, `lock` is already held; trying
    ///     to acquire it again from inside `_state` is a same-thread re-acquire of a
    ///     non-reentrant `UnfairLock` (undefined behavior / hang).
    ///   - Across threads, the chain `lock → _state` on one thread and `_state → lock` on
    ///     another forms a classic lock-order inversion / deadlock.
    /// Keep this method to storage-only writes. Storage has its own internal serialization
    /// and does not interact with either lock.
    func backfillTerminationReasonOnLatestPart(_ reason: TerminationReason) {
        guard let storage = storage,
            let latest = storage.fetchLatestSession(),
            latest.userSessionTerminationReason == nil
        else {
            return
        }
        storage.updateSession(session: latest, userSessionTerminationReason: reason)
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
