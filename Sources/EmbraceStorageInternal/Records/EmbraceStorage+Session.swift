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
    ) -> SessionRecord {

        // update existing?
        if let session = fetchSession(id: id) {
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

            coreData.save()
            return session
        }

        // create new
        let session = SessionRecord.create(
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
        )

        coreData.save()

        return session
    }

    /// Fetches the stored `SessionRecord` synchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    /// - Returns: The stored `SessionRecord`, if any
    public func fetchSession(id: SessionIdentifier) -> SessionRecord? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "idRaw == %@", id.toString)

        return coreData.fetch(withRequest: request).first
    }

    /// Synchronously fetches the newest session in the storage, ignoring the current session if it exists.
    /// - Returns: The newest stored `SessionRecord`, if any
    public func fetchLatestSession(ignoringCurrentSessionId sessionId: SessionIdentifier? = nil) -> SessionRecord? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        if let sessionId = sessionId {
            request.predicate = NSPredicate(format: "idRaw != %@", sessionId.toString)
        }

        return coreData.fetch(withRequest: request).first
    }

    /// Synchronously fetches the oldest session in the storage, if any.
    /// - Returns: The oldest stored `SessionRecord`, if any
    public func fetchOldestSession() -> SessionRecord? {
        let request = SessionRecord.createFetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

        return coreData.fetch(withRequest: request).first
    }
}
