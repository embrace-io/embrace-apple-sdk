//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension EmbraceStorage {

    /// Adds a session to the storage asynchronously; the record is created and saved on the storage queue.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - processId: `ProcessIdentifier` of the session
    ///   - state: `SessionState` of the session
    ///   - traceId: String representing the trace identifier of the corresponding session span
    ///   - spanId: String representing the span identifier of the corresponding session span
    ///   - startTime: `Date` of when the session started
    ///   - endTime: `Date` of when the session ended (optional)
    ///   - lastHeartbeatTime: `Date` of the last heartbeat for the session (optional).
    ///   - crashReportId: Identifier of the crash report linked with this session
    ///   - sessionNumber: Number of the session. Ignored when `sessionNumberCounterKey` is set.
    ///   - sessionNumberCounterKey: Key of a permanent counter resource. When set, the counter is incremented
    ///     in the same storage-queue block that creates the record, and its new value becomes the stored
    ///     session's number. The returned copy then has a `sessionNumber` of 0; fetch the stored session to read it.
    ///   - resolveUserSession: When set, called on the storage queue right before the record is created, and the
    ///     user session it returns replaces the `userSession*` values (except the termination reason). Every
    ///     operation queued before this call has run by then, and the async operations it issues on this storage
    ///     run right away, before the record exists (see `CoreDataWrapper.performAsyncOperationsInline`).
    ///     The returned copy then has no user session; fetch the stored session to read it.
    ///   - completion: A block called when the session has been added to storage
    /// - Returns: An in-memory copy of the session built from the given values, returned without waiting for the record to be stored.
    @discardableResult
    package func addSession(
        id: EmbraceIdentifier,
        processId: EmbraceIdentifier,
        state: SessionState,
        traceId: String,
        spanId: String,
        startTime: Date,
        endTime: Date? = nil,
        lastHeartbeatTime: Date? = nil,
        crashReportId: String? = nil,
        coldStart: Bool = false,
        cleanExit: Bool = false,
        appTerminated: Bool = false,
        sessionNumber: EMBInt = 0,
        userSessionId: EmbraceIdentifier? = nil,
        userSessionStartTime: Date? = nil,
        userSessionMaxDuration: TimeInterval? = nil,
        userSessionInactivityTimeout: TimeInterval? = nil,
        userSessionLastForegroundEnd: Date? = nil,
        userSessionPartIndex: EMBInt = 0,
        userSessionTerminationReason: TerminationReason? = nil,
        sessionNumberCounterKey: String? = nil,
        resolveUserSession: (() -> EmbraceUserSession?)? = nil,
        completion: (() -> Void)? = nil
    ) -> EmbraceSession? {

        let hbTime = lastHeartbeatTime ?? Date()

        coreData.performAsyncOperation { [self] context in

            defer {
                if let completion {
                    DispatchQueue.global(qos: .default).async {
                        completion()
                    }
                }
            }

            var userSession: EmbraceUserSession?
            if let resolveUserSession {
                coreData.performAsyncOperationsInline {
                    userSession = resolveUserSession()
                }
            }

            let number =
                sessionNumberCounterKey.map {
                    incrementCountForPermanentResource(key: $0, context: context)
                } ?? sessionNumber

            let created = SessionRecord.create(
                context: coreData.context,
                id: id,
                processId: processId,
                state: state,
                traceId: traceId,
                spanId: spanId,
                startTime: startTime,
                endTime: endTime,
                lastHeartbeatTime: hbTime,
                coldStart: coldStart,
                cleanExit: cleanExit,
                appTerminated: appTerminated,
                sessionNumber: number,
                userSessionId: resolveUserSession == nil ? userSessionId : userSession?.id,
                userSessionStartTime: resolveUserSession == nil ? userSessionStartTime : userSession?.startTime,
                userSessionMaxDuration: resolveUserSession == nil ? userSessionMaxDuration : userSession?.maxDuration,
                userSessionInactivityTimeout: resolveUserSession == nil
                    ? userSessionInactivityTimeout : userSession?.inactivityTimeout,
                userSessionLastForegroundEnd: resolveUserSession == nil
                    ? userSessionLastForegroundEnd : userSession?.lastForegroundPartEnd,
                userSessionPartIndex: resolveUserSession == nil ? userSessionPartIndex : (userSession?.partIndex ?? 0),
                userSessionTerminationReason: userSessionTerminationReason
            )
            guard created else {
                logger.critical("Failed to create new session!")
                return
            }

            coreData.save()
        }

        return ImmutableSessionRecord(
            id: id,
            processId: processId,
            state: state,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: hbTime,
            crashReportId: crashReportId,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            sessionNumber: sessionNumberCounterKey == nil ? sessionNumber : 0,
            userSessionId: resolveUserSession == nil ? userSessionId : nil,
            userSessionStartTime: resolveUserSession == nil ? userSessionStartTime : nil,
            userSessionMaxDuration: resolveUserSession == nil ? userSessionMaxDuration : nil,
            userSessionInactivityTimeout: resolveUserSession == nil ? userSessionInactivityTimeout : nil,
            userSessionLastForegroundEnd: resolveUserSession == nil ? userSessionLastForegroundEnd : nil,
            userSessionPartIndex: resolveUserSession == nil ? userSessionPartIndex : 0,
            userSessionTerminationReason: userSessionTerminationReason
        )
    }

    func fetchSessionRequest(id: EmbraceIdentifier) -> NSFetchRequest<SessionRecord> {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "idRaw == %@", id.stringValue)
        return request
    }

    /// Fetches the stored `SessionRecord` synchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    /// - Returns: Immutable copy of the stored `SessionRecord`, if any
    package func fetchSession(id: EmbraceIdentifier) -> EmbraceSession? {

        // fetch
        let request = fetchSessionRequest(id: id)
        var result: EmbraceSession?
        coreData.fetchFirstAndPerform(withRequest: request) { record, _ in
            // convert to immutable struct
            result = record?.toImmutable()
        }

        return result
    }

    /// Asynchronously deletes the given session from the storage
    public func deleteSession(id: EmbraceIdentifier) {
        let request = fetchSessionRequest(id: id)
        coreData.deleteRecordsAsync(withRequest: request)
    }

    /// Synchronously fetches the newest session in the storage, ignoring the current session if it exists.
    /// - Returns: Immutable copy of the newest stored `SessionRecord`, if any
    package func fetchLatestSession(
        ignoringCurrentSessionId sessionId: EmbraceIdentifier? = nil
    ) -> EmbraceSession? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        if let sessionId = sessionId {
            request.predicate = NSPredicate(format: "idRaw != %@", sessionId.stringValue)
        }

        // fetch
        var result: EmbraceSession?
        coreData.fetchFirstAndPerform(withRequest: request) { record, _ in
            // convert to immutable struct
            result = record?.toImmutable()
        }

        return result
    }

    /// Completion will be sent on an undefined queue.
    package func fetchLatestSession(
        ignoringCurrentSessionId sessionId: EmbraceIdentifier? = nil,
        _ completion: @escaping (EmbraceSession?) -> Void
    ) {
        coreData.performAsyncOperation { [self] _ in

            let request = SessionRecord.createFetchRequest()
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            if let sessionId = sessionId {
                request.predicate = NSPredicate(format: "idRaw != %@", sessionId.stringValue)
            }

            if let session = coreData.fetch(withRequest: request).first {
                let result = session.toImmutable()
                DispatchQueue.global(qos: .default).async {
                    completion(result)
                }
            } else {
                DispatchQueue.global(qos: .default).async {
                    completion(nil)
                }
            }
        }
    }

    /// Synchronously fetches the oldest session in the storage, if any.
    /// - Returns: Immutable copy of the oldest stored `SessionRecord`, if any
    package func fetchOldestSession(ignoringCurrentSessionId sessionId: EmbraceIdentifier? = nil) -> EmbraceSession? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

        if let sessionId = sessionId {
            request.predicate = NSPredicate(format: "idRaw != %@", sessionId.stringValue)
        }

        // fetch
        var result: EmbraceSession?
        coreData.fetchFirstAndPerform(withRequest: request) { record, _ in
            // convert to immutable struct
            result = record?.toImmutable()
        }

        return result
    }

    /// Synchronously fetches all the sessions in the storage, if any
    /// - Returns: Immutable copies of all the stored sessions
    package func fetchAllSessions() -> [EmbraceSession] {
        let request = SessionRecord.createFetchRequest()

        // fetch
        var result: [EmbraceSession] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in
            // convert to immutable struct
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Updates values for the given session id
    /// - Returns: An in-memory copy of the given session with the given values applied.
    ///   The record is updated asynchronously, and values only set by the storage (like the session number, or a deferred part's user session) aren't refreshed.
    @discardableResult
    package func updateSession(
        session: EmbraceSession,
        state: SessionState? = nil,
        lastHeartbeatTime: Date? = nil,
        endTime: Date? = nil,
        cleanExit: Bool? = nil,
        appTerminated: Bool? = nil,
        crashReportId: String? = nil,
        userSessionLastForegroundEnd: Date? = nil,
        userSessionTerminationReason: TerminationReason? = nil
    ) -> EmbraceSession? {

        coreData.performAsyncOperation { [self] context in

            let request = fetchSessionRequest(id: session.id)
            let fetchedSession = coreData.fetch(withRequest: request).first
            guard let fetchedSession else {
                return
            }

            if let state = state {
                fetchedSession.state = state.rawValue
            }

            if let lastHeartbeatTime = lastHeartbeatTime {
                fetchedSession.lastHeartbeatTime = lastHeartbeatTime
            }

            if let endTime = endTime {
                fetchedSession.endTime = endTime
            }

            if let cleanExit = cleanExit {
                fetchedSession.cleanExit = cleanExit
            }

            if let appTerminated = appTerminated {
                fetchedSession.appTerminated = appTerminated
            }

            if let crashReportId = crashReportId {
                fetchedSession.crashReportId = crashReportId
            }

            if let userSessionLastForegroundEnd = userSessionLastForegroundEnd {
                fetchedSession.userSessionLastForegroundEnd = userSessionLastForegroundEnd
            }

            if let userSessionTerminationReason = userSessionTerminationReason {
                fetchedSession.userSessionTerminationReason = userSessionTerminationReason.rawValue
            }

            coreData.save()
        }

        return session.updated(
            state: state,
            lastHeartbeatTime: lastHeartbeatTime,
            endTime: endTime,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            crashReportId: crashReportId,
            userSessionLastForegroundEnd: userSessionLastForegroundEnd,
            userSessionTerminationReason: userSessionTerminationReason
        )
    }

    /// Asynchronously stamps the given user session termination reason on the newest stored session,
    /// unless that session already has one.
    ///
    /// The lookup runs on the storage context when the operation executes, so the "newest" session is
    /// resolved against every operation queued before this call, and none queued after it.
    package func setUserSessionTerminationReasonOnLatestSessionIfNeeded(_ reason: TerminationReason) {
        coreData.performAsyncOperation { [self] _ in

            let request = SessionRecord.createFetchRequest()
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            guard let latest = coreData.fetch(withRequest: request).first,
                latest.userSessionTerminationReason == nil
            else {
                return
            }

            latest.userSessionTerminationReason = reason.rawValue
            coreData.save()
        }
    }
}

extension EmbraceSession {
    /// Returns a copy of this session that belongs to the given user session, with the values a part record
    /// takes from it when it's created.
    package func with(userSession: EmbraceUserSession) -> EmbraceSession {
        return ImmutableSessionRecord(
            id: id,
            processId: processId,
            state: state,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime,
            crashReportId: crashReportId,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            sessionNumber: sessionNumber,
            userSessionId: userSession.id,
            userSessionStartTime: userSession.startTime,
            userSessionMaxDuration: userSession.maxDuration,
            userSessionInactivityTimeout: userSession.inactivityTimeout,
            userSessionLastForegroundEnd: userSession.lastForegroundPartEnd,
            userSessionPartIndex: userSession.partIndex,
            userSessionTerminationReason: userSessionTerminationReason
        )
    }

    /// Returns a copy of this session with the values that only the storage assigns taken from `stored`, the
    /// session's stored record: the part number and, if this copy has no user session, the user session.
    /// Everything else (like the termination reason, which is only backfilled into the record) is this copy's.
    package func withStorageAssignedValues(from stored: EmbraceSession) -> EmbraceSession {
        let userSessionSource: EmbraceSession = userSessionId == nil ? stored : self
        return ImmutableSessionRecord(
            id: id,
            processId: processId,
            state: state,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime,
            crashReportId: crashReportId,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            sessionNumber: stored.sessionNumber,
            userSessionId: userSessionSource.userSessionId,
            userSessionStartTime: userSessionSource.userSessionStartTime,
            userSessionMaxDuration: userSessionSource.userSessionMaxDuration,
            userSessionInactivityTimeout: userSessionSource.userSessionInactivityTimeout,
            userSessionLastForegroundEnd: userSessionLastForegroundEnd ?? userSessionSource.userSessionLastForegroundEnd,
            userSessionPartIndex: userSessionSource.userSessionPartIndex,
            userSessionTerminationReason: userSessionTerminationReason
        )
    }

    /// Returns a copy of this session with the user-session values of `other`.
    package func with(userSessionOf other: EmbraceSession) -> EmbraceSession {
        return ImmutableSessionRecord(
            id: id,
            processId: processId,
            state: state,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime,
            crashReportId: crashReportId,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            sessionNumber: sessionNumber,
            userSessionId: other.userSessionId,
            userSessionStartTime: other.userSessionStartTime,
            userSessionMaxDuration: other.userSessionMaxDuration,
            userSessionInactivityTimeout: other.userSessionInactivityTimeout,
            userSessionLastForegroundEnd: userSessionLastForegroundEnd ?? other.userSessionLastForegroundEnd,
            userSessionPartIndex: other.userSessionPartIndex,
            userSessionTerminationReason: userSessionTerminationReason ?? other.userSessionTerminationReason
        )
    }

    func updated(
        state: SessionState? = nil,
        lastHeartbeatTime: Date? = nil,
        endTime: Date? = nil,
        cleanExit: Bool? = nil,
        appTerminated: Bool? = nil,
        crashReportId: String? = nil,
        userSessionLastForegroundEnd: Date? = nil,
        userSessionTerminationReason: TerminationReason? = nil
    ) -> EmbraceSession {

        return ImmutableSessionRecord(
            id: id,
            processId: processId,
            state: state ?? self.state,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime ?? self.endTime,
            lastHeartbeatTime: lastHeartbeatTime ?? self.lastHeartbeatTime,
            crashReportId: crashReportId ?? self.crashReportId,
            coldStart: coldStart,
            cleanExit: cleanExit ?? self.cleanExit,
            appTerminated: appTerminated ?? self.appTerminated,
            sessionNumber: self.sessionNumber,
            userSessionId: self.userSessionId,
            userSessionStartTime: self.userSessionStartTime,
            userSessionMaxDuration: self.userSessionMaxDuration,
            userSessionInactivityTimeout: self.userSessionInactivityTimeout,
            userSessionLastForegroundEnd: userSessionLastForegroundEnd ?? self.userSessionLastForegroundEnd,
            userSessionPartIndex: self.userSessionPartIndex,
            userSessionTerminationReason: userSessionTerminationReason ?? self.userSessionTerminationReason
        )
    }
}
