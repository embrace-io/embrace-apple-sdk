//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import EmbraceStorageInternal
#endif

extension Notification.Name {
    /// Posted when a new user session is created. The `object` is the freshly-created
    /// `EmbraceUserSession` snapshot. Posted async on the main queue so listeners cannot
    /// re-enter the controller under its lock.
    public static let embraceUserSessionDidStart = Notification.Name("embrace.user_session.did_start")

    /// Posted when a user session ends. The `object` is the `EmbraceUserSession` snapshot
    /// that just terminated. Posted async on the main queue so listeners cannot re-enter
    /// the controller under its lock.
    public static let embraceUserSessionDidEnd = Notification.Name("embrace.user_session.did_end")
}

/// Owns the in-memory `EmbraceUserSession` snapshot and resolves which user session a new
/// part belongs to.
///
/// A user session is bounded by two cutoffs:
/// - `maxDuration`: total wall-clock duration from the user session's start time.
/// - `inactivityTimeout`: time after the most recent foreground-part end before the user
///   session expires.
///
/// The controller is the single source of truth for "which user session does this part belong to?".
/// It is consumed by `SessionController` (which calls `attachPart` before creating a part record)
/// and exposes `bootstrap()` for cold-start reconstruction from the latest persisted `SessionRecord`.
///
/// All cutoff math uses wall-clock `Date()`; `dateProvider` is injected for tests.
///
/// - Important: `bootstrap()` MUST run before unsent data is uploaded — the previous process's
///   last part is the source of our user-session reconstruction. If that record is uploaded and
///   deleted first, the snapshot is lost and a fresh user session starts on the next part.
final class UserSessionController {

    /// Minimum interval between accepted manual end-user-session calls. Prevents customers from
    /// overwhelming the backend by calling the manual end API in a tight loop.
    private static let manualEndMinInterval: TimeInterval = 5.0

    /// Combined state held under a single mutex. Splitting these would force two locks for the
    /// invariants (snapshot vs counters) to stay consistent across an `attachPart` decision.
    private struct State {
        var session: ImmutableUserSession?
        var lastManualEnd: Date?
    }

    private let _state: EmbraceMutex<State> = EmbraceMutex(State(session: nil, lastManualEnd: nil))

    weak var storage: EmbraceStorage?
    weak var config: EmbraceConfigurable?
    weak var sessionController: SessionController?

    private let dateProvider: () -> Date

    var currentUserSession: EmbraceUserSession? {
        _state.withLock { $0.session }
    }

    var currentUserSessionId: EmbraceIdentifier? {
        currentUserSession?.id
    }

    init(
        storage: EmbraceStorage,
        config: EmbraceConfigurable,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.storage = storage
        self.config = config
        self.dateProvider = dateProvider
    }

    // MARK: - Bootstrap

    /// Reconstructs the in-memory snapshot from the prior process's most recent persisted
    /// `SessionRecord`. Call once at SDK start, before `sessionLifecycle.startSession()` and
    /// before `UnsentDataHandler.sendUnsentData`.
    ///
    /// If the prior record has no user-session columns (legacy v6 row) or no record exists,
    /// the snapshot is left empty and the next `attachPart` call starts a new user session
    /// from scratch.
    ///
    /// If the reconstructed user session is already expired by the time bootstrap runs, the
    /// termination is routed through `internalEndUserSession` — same path as a mid-session
    /// expiry detected by `attachPart`. The termination reason is backfilled onto the prior
    /// part record (no-op if the prior process already stamped one) and the user-session-end
    /// notification fires, so cold-start expiry produces the same telemetry as mid-session
    /// expiry instead of silently dropping the snapshot.
    func bootstrap(priorSession: EmbraceSession?) {
        guard
            let latest = priorSession,
            let userSessionId = latest.userSessionId,
            let userSessionStartTime = latest.userSessionStartTime
        else {
            return
        }

        let maxDuration = latest.userSessionMaxDuration ?? config?.userSessionMaxDuration ?? UserSessionSemantics.defaultMaxDurationSeconds
        let inactivityTimeout =
            latest.userSessionInactivityTimeout ?? config?.userSessionInactivityTimeout ?? UserSessionSemantics.defaultInactivityTimeoutSeconds

        let snapshot = ImmutableUserSession(
            id: userSessionId,
            startTime: userSessionStartTime,
            maxDuration: maxDuration,
            inactivityTimeout: inactivityTimeout,
            lastForegroundPartEnd: latest.userSessionLastForegroundEnd,
            partIndex: max(latest.userSessionPartIndex, 1),
            endTime: nil,
            terminationReason: nil
        )

        let now = dateProvider()
        if let reason = Self.expiryReason(snapshot: snapshot, at: now) {
            internalEndUserSession(snapshot: snapshot, reason: reason, at: now)
            return
        }

        _state.withLock { $0.session = snapshot }
    }

    // MARK: - attachPart

    /// Resolves which user session a brand-new part belongs to.
    ///
    /// Called from `SessionController.startSession` before the new `SessionRecord` is inserted.
    /// The returned snapshot's `partIndex` is the index the caller should stamp on the new part.
    ///
    /// If there is no active user session, or the active one has expired (max duration reached,
    /// inactivity timeout exceeded, or device clock moved backward past the user-session start),
    /// the active user session is terminated and a new one is created. Otherwise the part joins
    /// the active user session — its `lastForegroundPartEnd` is cleared (no inactivity cutoff
    /// applies during a part) and `partIndex` is bumped.
    ///
    /// - Parameters:
    ///   - state: The state of the part being created (foreground/background).
    ///   - startTime: The wall-clock start time of the new part.
    /// - Returns: The user-session snapshot the new part will belong to.
    @discardableResult
    func attachPart(state newPartState: SessionState, startTime: Date) -> EmbraceUserSession {
        var pendingEnd: (snapshot: ImmutableUserSession, reason: TerminationReason)?

        let snapshot: EmbraceUserSession = _state.withLock { mutableState in

            // No active user session -> start new one
            guard let snapshot = mutableState.session else {
                return startNewUserSession(state: &mutableState, at: startTime)
            }

            // Active user session should be terminated -> capture inputs, end after lock release
            if let reason = Self.expiryReason(snapshot: snapshot, at: startTime) {
                pendingEnd = (snapshot, reason)
                return startNewUserSession(state: &mutableState, at: startTime)
            }

            // Active user session still valid -> bump part index. Only foreground parts clear
            // the inactivity cutoff (`lastForegroundPartEnd`) — background parts must preserve
            // it so the next foreground transition can still apply the bg-split cutoff math.
            let nextIndex = snapshot.partIndex + 1
            let updated =
                newPartState == .foreground
                ? snapshot.cleared(partIndex: nextIndex)
                : snapshot.bumping(partIndex: nextIndex)
            mutableState.session = updated
            return updated
        }

        if let pendingEnd {
            internalEndUserSession(snapshot: pendingEnd.snapshot, reason: pendingEnd.reason, at: startTime)
        }
        return snapshot
    }

    // MARK: - Foreground tracking

    /// Records the most recent foreground-part end time on the in-memory snapshot. The
    /// corresponding storage write (`userSessionLastForegroundEnd` on the part record) is
    /// performed by `SessionController.endSessionNoLock`, which avoids holding this lock
    /// across Core Data writes.
    func markForegroundPartEnded(at endTime: Date) {
        _state.withLock { state in
            guard let snapshot = state.session else {
                return
            }
            state.session = snapshot.setting(lastForegroundPartEnd: endTime)
        }
    }

    // MARK: - Termination

    /// Ends the active user session with the given reason. Idempotent — calling with no active
    /// user session is a silent no-op.
    func endActiveUserSession(reason: TerminationReason, at endTime: Date) {
        var pendingEnd: ImmutableUserSession?

        _state.withLock { state in
            guard let snapshot = state.session else {
                return
            }
            pendingEnd = snapshot
            state.session = nil
        }

        if let pendingEnd {
            internalEndUserSession(snapshot: pendingEnd, reason: reason, at: endTime)
        }
    }

    // MARK: - Manual-end rate limit

    /// Returns `true` if a manual end-user-session call is allowed at `now` (i.e., at least
    /// `manualEndMinInterval` has elapsed since the last allowed manual end). Records `now` as
    /// the last allowed call when it returns `true`.
    func canManuallyEnd(now: Date) -> Bool {
        _state.withLock { state in
            if let last = state.lastManualEnd, now.timeIntervalSince(last) < Self.manualEndMinInterval {
                return false
            }
            state.lastManualEnd = now
            return true
        }
    }

    // MARK: - Private helpers

    /// Starts a brand-new user session. Mutates `state` in place. Caller holds the mutex.
    private func startNewUserSession(state: inout State, at startTime: Date) -> ImmutableUserSession {
        let maxDuration = config?.userSessionMaxDuration ?? UserSessionSemantics.defaultMaxDurationSeconds
        let inactivityTimeout = config?.userSessionInactivityTimeout ?? UserSessionSemantics.defaultInactivityTimeoutSeconds

        let snapshot = ImmutableUserSession(
            id: EmbraceIdentifier.random,
            startTime: startTime,
            maxDuration: maxDuration,
            inactivityTimeout: inactivityTimeout,
            lastForegroundPartEnd: nil,
            partIndex: 1,
            endTime: nil,
            terminationReason: nil
        )
        state.session = snapshot
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .embraceUserSessionDidStart, object: snapshot)
        }
        return snapshot
    }

    /// Stamps the termination reason on the just-closed part record (if any) and posts the
    /// `embraceUserSessionDidEnd` notification.
    ///
    /// - Important: MUST be called OUTSIDE `_state.withLock`. Performs a synchronous Core Data
    ///   fetch via `backfillTerminationReasonOnLatestPart`; holding the mutex across it would
    ///   block `currentUserSession` readers on the heartbeat and bg-split paths.
    private func internalEndUserSession(
        snapshot: ImmutableUserSession,
        reason: TerminationReason,
        at endTime: Date
    ) {
        sessionController?.backfillTerminationReasonOnLatestPart(reason)

        let terminated = snapshot.terminated(at: endTime, reason: reason)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .embraceUserSessionDidEnd, object: terminated)
        }
    }

    /// Returns the termination reason if the snapshot has expired at `now`, else `nil`.
    /// The cutoff boundaries are inclusive — a part starting exactly at the cutoff is treated
    /// as expired so the bg-split path (which starts a synthetic part *at* the cutoff) cleanly
    /// rolls into a new user session.
    /// Inactivity cutoff is only applicable when there is a `lastForegroundPartEnd`.
    private static func expiryReason(snapshot: ImmutableUserSession, at now: Date) -> TerminationReason? {
        if now < snapshot.startTime {
            return .clockAnomaly
        }
        if let lastFgEnd = snapshot.lastForegroundPartEnd, now < lastFgEnd {
            return .clockAnomaly
        }
        if now >= snapshot.maxEnd {
            return .maxDurationReached
        }
        if let lastFgEnd = snapshot.lastForegroundPartEnd {
            let inactivityCutoff = lastFgEnd.addingTimeInterval(snapshot.inactivityTimeout)
            if now >= inactivityCutoff {
                return .inactivity
            }
        }
        return nil
    }
}

extension ImmutableUserSession {
    /// Bumps `partIndex` without touching `lastForegroundPartEnd`. Used when a background
    /// part joins an existing user session — the inactivity cutoff must persist across the
    /// bg interval so the next foreground-transition's split math still has it.
    fileprivate func bumping(partIndex: EMBInt) -> ImmutableUserSession {
        return ImmutableUserSession(
            id: id,
            startTime: startTime,
            maxDuration: maxDuration,
            inactivityTimeout: inactivityTimeout,
            lastForegroundPartEnd: lastForegroundPartEnd,
            partIndex: partIndex,
            endTime: endTime,
            terminationReason: terminationReason
        )
    }

    /// Clears `lastForegroundPartEnd` and bumps `partIndex`. Used when a foreground part joins
    /// an existing user session: an active fg part invalidates any pending inactivity cutoff
    /// (the cutoff only applies between foreground parts, not while one is active), and the
    /// new index reflects the part being attached.
    fileprivate func cleared(partIndex: EMBInt) -> ImmutableUserSession {
        return ImmutableUserSession(
            id: id,
            startTime: startTime,
            maxDuration: maxDuration,
            inactivityTimeout: inactivityTimeout,
            lastForegroundPartEnd: nil,
            partIndex: partIndex,
            endTime: endTime,
            terminationReason: terminationReason
        )
    }

    fileprivate func setting(lastForegroundPartEnd: Date) -> ImmutableUserSession {
        return ImmutableUserSession(
            id: id,
            startTime: startTime,
            maxDuration: maxDuration,
            inactivityTimeout: inactivityTimeout,
            lastForegroundPartEnd: lastForegroundPartEnd,
            partIndex: partIndex,
            endTime: endTime,
            terminationReason: terminationReason
        )
    }

    fileprivate func terminated(at endTime: Date, reason: TerminationReason) -> ImmutableUserSession {
        return ImmutableUserSession(
            id: id,
            startTime: startTime,
            maxDuration: maxDuration,
            inactivityTimeout: inactivityTimeout,
            lastForegroundPartEnd: lastForegroundPartEnd,
            partIndex: partIndex,
            endTime: endTime,
            terminationReason: reason
        )
    }
}
