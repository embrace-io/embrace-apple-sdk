//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

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
        id: SessionIdentifier,
        processId: ProcessIdentifier,
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

        // update existing?
        if let session = fetchSessionRecord(id: id) {
            var result: EmbraceSession?

            coreData.context.performAndWait {
                session.state = state.rawValue
                session.processIdRaw = processId.hex
                session.traceId = traceId
                session.spanId = spanId
                session.startTime = startTime
                session.endTime = endTime
                session.crashReportId = crashReportId
                session.coldStart = coldStart
                session.cleanExit = cleanExit
                session.appTerminated = appTerminated

                if let lastHeartbeatTime = lastHeartbeatTime {
                    session.lastHeartbeatTime = lastHeartbeatTime
                }

                result = session.toImmutable()

                do {
                    try coreData.context.save()
                } catch {
                    logger.error("Error updating session \(id.toString)!")
                }
            }

            return result
        }

        // create new
        if let session = SessionRecord.create(
            context: coreData.context,
            id: id,
            processId: processId,
            state: state,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime,
            coldStart: coldStart,
            cleanExit: cleanExit,
            appTerminated: appTerminated
        ) {
            coreData.save()
            return session
        }

        return nil
    }

    /// Fetches the stored `SessionRecord` synchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    /// - Returns: The stored `SessionRecord`, if any
    func fetchSessionRecord(id: SessionIdentifier) -> SessionRecord? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "idRaw == %@", id.toString)

        return coreData.fetch(withRequest: request).first
    }

    /// Fetches the stored `SessionRecord` synchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    /// - Returns: Immutable copy of the stored `SessionRecord`, if any
    public func fetchSession(id: SessionIdentifier) -> EmbraceSession? {
        guard let record = fetchSessionRecord(id: id) else {
            return nil
        }

        var result: EmbraceSession?
        coreData.context.performAndWait {
            result = record.toImmutable()
        }
        return result
    }

    /// Synchronously deletes the given session from the storage
    public func deleteSession(id: SessionIdentifier) {
        guard let record = fetchSessionRecord(id: id) else {
            return
        }

        coreData.deleteRecord(record)
    }

    /// Synchronously fetches the newest session in the storage, ignoring the current session if it exists.
    /// - Returns: Immutable copy of the newest stored `SessionRecord`, if any
    public func fetchLatestSession(ignoringCurrentSessionId sessionId: SessionIdentifier? = nil) -> EmbraceSession? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        if let sessionId = sessionId {
            request.predicate = NSPredicate(format: "idRaw != %@", sessionId.toString)
        }

        guard let record = coreData.fetch(withRequest: request).first else {
            return nil
        }

        var result: EmbraceSession?
        coreData.context.performAndWait {
            result = record.toImmutable()
        }
        return result
    }

    /// Synchronously fetches the oldest session in the storage, if any.
    /// - Returns: Immutable copy of the oldest stored `SessionRecord`, if any
    public func fetchOldestSession() -> EmbraceSession? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

        guard let record = coreData.fetch(withRequest: request).first else {
            return nil
        }

        var result: EmbraceSession?
        coreData.context.performAndWait {
            result = record.toImmutable()
        }
        return result
    }

    /// Synchronously fetches all the sessions in the storage, if any
    /// - Returns: Immutable copies of all the stored sessions
    public func fetchAllSessions() -> [EmbraceSession] {
        let request = SessionRecord.createFetchRequest()

        // fetch
        let records = coreData.fetch(withRequest: request)

        // convert to immutable structs
        var result: [EmbraceSession] = []
        coreData.context.performAndWait {
            result = records.map { $0.toImmutable() }
        }

        return result
    }
    
    /// Updates values for the given session id
    /// - Returns: Immutable copy of the modified `SessionRecord`, if any
    @discardableResult
    public func updateSession(
        sessionId: SessionIdentifier,
        state: SessionState? = nil,
        lastHeartbeatTime: Date? = nil,
        endTime: Date? = nil,
        cleanExit: Bool? = nil,
        appTerminated: Bool? = nil,
        crashReportId: String? = nil
    ) -> EmbraceSession? {
        guard let session = fetchSessionRecord(id: sessionId) else {
            return nil
        }

        var result: EmbraceSession?

        coreData.context.performAndWait {
            if let state = state {
                session.state = state.rawValue
            }

            if let lastHeartbeatTime = lastHeartbeatTime {
                session.lastHeartbeatTime = lastHeartbeatTime
            }

            if let endTime = endTime {
                session.endTime = endTime
            }

            if let cleanExit = cleanExit {
                session.cleanExit = cleanExit
            }

            if let appTerminated = appTerminated {
                session.appTerminated = appTerminated
            }

            if let crashReportId = crashReportId {
                session.crashReportId = crashReportId
            }

            result = session.toImmutable()

            do {
                try coreData.context.save()
            } catch {
                logger.error("Error updating session \(sessionId.toString)!")
            }
        }

        return result
    }
}
