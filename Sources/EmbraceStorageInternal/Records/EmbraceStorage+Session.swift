//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import GRDB

extension EmbraceStorage {
    /// Adds a session to the storage synchronously.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - state: `SessionState` of the session
    ///   - processId: `ProcessIdentifier` of the session
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
        state: SessionState,
        processId: ProcessIdentifier,
        traceId: String,
        spanId: String,
        startTime: Date,
        endTime: Date? = nil,
        lastHeartbeatTime: Date? = nil,
        crashReportId: String? = nil
    ) throws -> SessionRecord {
        let session = SessionRecord(
            id: id,
            state: state,
            processId: processId,
            traceId: traceId,
            spanId: spanId,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartbeatTime
        )

        try upsertSession(session)

        return session
    }

    /// Adds or updates a `SessionRecord` to the storage synchronously.
    /// - Parameter record: `SessionRecord` to insert
    public func upsertSession(_ session: SessionRecord) throws {
        try dbQueue.write { db in
            try session.insert(db)
        }
    }

    /// Fetches the stored `SessionRecord` synchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    /// - Returns: The stored `SessionRecord`, if any

    public func fetchSession(id: SessionIdentifier) throws -> SessionRecord? {
        try dbQueue.read { db in
            return try SessionRecord.fetchOne(db, key: id)
        }
    }

    /// Synchronously fetches the newest session in the storage, ignoring the current session if it exists.
    /// - Returns: The newest stored `SessionRecord`, if any
    public func fetchLatestSession(
        ignoringCurrentSessionId sessionId: SessionIdentifier? = nil
    ) throws -> SessionRecord? {
        var session: SessionRecord?
        try dbQueue.read { db in

            var filter = SessionRecord.order(SessionRecord.Schema.startTime.desc)

            if let sessionId = sessionId {
                filter = filter.filter(SessionRecord.Schema.id != sessionId)
            }

            session = try filter.fetchOne(db)
        }

        return session
    }

    /// Synchronously fetches the oldest session in the storage, if any.
    /// - Returns: The oldest stored `SessionRecord`, if any
    public func fetchOldestSession() throws -> SessionRecord? {
        var session: SessionRecord?
        try dbQueue.read { db in
            session = try SessionRecord
                .order(SessionRecord.Schema.startTime.asc)
                .fetchOne(db)
        }

        return session
    }
}
