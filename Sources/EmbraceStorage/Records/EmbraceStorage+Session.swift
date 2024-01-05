//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

// MARK: - Sync session operations
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
    @discardableResult public func addSession(
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

    /// Synchronously fetches the newest session in the storage, if any.
    /// - Returns: The newest stored `SessionRecord`, if any
    public func fetchLatestSesssion() throws -> SessionRecord? {
        var session: SessionRecord?
        try dbQueue.read { db in
            session = try SessionRecord
                .order(Column("start_time").desc)
                .fetchOne(db)
        }

        return session
    }

    /// Synchronously fetches the oldest session in the storage, if any.
    /// - Returns: The oldest stored `SessionRecord`, if any
    public func fetchOldestSesssion() throws -> SessionRecord? {
        var session: SessionRecord?
        try dbQueue.read { db in
            session = try SessionRecord
                .order(Column("start_time").asc)
                .fetchOne(db)
        }

        return session
    }
}
