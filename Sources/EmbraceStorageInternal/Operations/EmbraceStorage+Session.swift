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

    /// Adds a session to the storage synchronously.
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
    /// - Returns: The newly stored `SessionRecord`
    @discardableResult
    public func addSession(
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
        appTerminated: Bool = false
    ) -> EmbraceSession? {

        let hbTime = lastHeartbeatTime ?? Date()

        coreData.performAsyncOperation { [self] _ in

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
                appTerminated: appTerminated
            )
            guard created else {
                logger.critical("Failed to create new session!")
                return
            }

            do {
                try coreData.context.save()
            } catch {
                logger.critical("Failed to save new session!")
            }
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
            appTerminated: appTerminated
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
    public func fetchSession(id: EmbraceIdentifier) -> EmbraceSession? {

        // fetch
        let request = fetchSessionRequest(id: id)
        var result: EmbraceSession?
        coreData.fetchFirstAndPerform(withRequest: request) { record, _ in
            // convert to immutable struct
            result = record?.toImmutable()
        }

        return result
    }

    /// Synchronously deletes the given session from the storage
    public func deleteSession(id: EmbraceIdentifier) {
        let request = fetchSessionRequest(id: id)
        coreData.deleteRecords(withRequest: request)
    }

    /// Synchronously fetches the newest session in the storage, ignoring the current session if it exists.
    /// - Returns: Immutable copy of the newest stored `SessionRecord`, if any
    public func fetchLatestSession(
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
    public func fetchLatestSession(
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
    public func fetchOldestSession(ignoringCurrentSessionId sessionId: EmbraceIdentifier? = nil) -> EmbraceSession? {
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
    public func fetchAllSessions() -> [EmbraceSession] {
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
    /// - Returns: Immutable copy of the modified `SessionRecord`, if any
    @discardableResult
    public func updateSession(
        session: EmbraceSession,
        state: SessionState? = nil,
        lastHeartbeatTime: Date? = nil,
        endTime: Date? = nil,
        cleanExit: Bool? = nil,
        appTerminated: Bool? = nil,
        crashReportId: String? = nil
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

            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                logger.critical("Failed to update session, error: \(error)")
            }
        }

        return session.updated(
            state: state,
            lastHeartbeatTime: lastHeartbeatTime,
            endTime: endTime,
            cleanExit: cleanExit,
            appTerminated: appTerminated,
            crashReportId: crashReportId
        )
    }
}

extension EmbraceSession {
    func updated(
        state: SessionState? = nil,
        lastHeartbeatTime: Date? = nil,
        endTime: Date? = nil,
        cleanExit: Bool? = nil,
        appTerminated: Bool? = nil,
        crashReportId: String? = nil
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
            appTerminated: appTerminated ?? self.appTerminated
        )
    }
}
