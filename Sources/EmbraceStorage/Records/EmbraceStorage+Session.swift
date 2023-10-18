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
    ///   - state: State of the session
    ///   - startTime: Date of when the session started
    ///   - endTime: Date of when the session ended (optional)
    ///   - crashReportId: Identifier of the crash report linked with this session
    /// - Returns: The newly stored `SessionRecord`
    @discardableResult public func addSession(id: SessionId, state: SessionState, startTime: Date, endTime: Date? = nil, crashReportId: String? = nil) throws -> SessionRecord {
        let session = SessionRecord(id: id, state: state, startTime: startTime, endTime: endTime)
        try upsertSession(session)

        return session
    }

    /// Adds or updates a `SessionRecord` to the storage synchronously.
    /// - Parameter record: `SessionRecord` to insert
    public func upsertSession(_ session: SessionRecord) throws {
        try dbQueue.write { [weak self] db in
            try self?.upsertSession(db: db, session: session)
        }
    }

    /// Fetches the stored `SessionRecord` synchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    /// - Returns: The stored `SessionRecord`, if any
    public func fetchSession(id: SessionId) throws -> SessionRecord? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchSession(db: db, id: id)
        }
    }

    /// Updates the `endTime` of a stored session synchronously.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - endTime: Date of when the session ended
    /// - Returns: The updated `SessionRecord`, if any
    @discardableResult public func updateSession(id: SessionId, endTime: Date) throws -> SessionRecord? {
        var session = try fetchSession(id: id)
        guard session != nil else {
            return nil
        }

        try dbQueue.write { [weak self] db in
            session = try self?.updateSession(db: db, session: session, endTime: endTime)
        }

        return session
    }

    /// Updates the `crashReportId` of a stored session synchronously.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - crashReportId: Identifier of the crash report linked with this session
    /// - Returns: The updated `SessionRecord`, if any
    @discardableResult public func updateSession(id: SessionId, crashReportId: String) throws -> SessionRecord? {
        var session = try fetchSession(id: id)
        guard session != nil else {
            return nil
        }

        try dbQueue.write { [weak self] db in
            session = try self?.updateSession(db: db, session: session, crashReportId: crashReportId)
        }

        return session
    }

    /// Returns how many finished sessions are stored synchronously. A finished session is a session with a valid `endTime`.
    /// - Returns: Int containing the amount of finished sessions in the storage
    public func finishedSessionsCount() throws -> Int {
        var count = 0
        try dbQueue.read { [weak self] db in
            count = try self?.finishedSessionsCount(db: db) ?? 0
        }

        return count
    }

    /// Returns all the finished sessions in the storage synchronously. A finished session is a session with a valid `endTime`.
    /// - Returns: Array containing the finished `SessionRecords`
    public func fetchFinishedSessions() throws -> [SessionRecord] {
        var sessions: [SessionRecord] = []
        try dbQueue.read { [weak self] db in
            sessions = try self?.fetchFinishedSessions(db: db) ?? []
        }

        return sessions
    }

    /// Synchronously returns the newest session in the storage, if any.
    /// - Returns: The newest stored `SessionRecord`, if any
    public func fetchLatestSesssion() throws -> SessionRecord? {
        var session: SessionRecord?
        try dbQueue.read { [weak self] db in
            session =  try self?.fetchLatestSessions(db: db)
        }

        return session
    }
}

// MARK: - Async session operations
extension EmbraceStorage {

    /// Adds a session to the storage asynchronously.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - state: State of the session
    ///   - startTime: Date of when the session started
    ///   - endTime: Date of when the session ended (optional)
    ///   - crashReportId: Identifier of the crash report linked with this session
    ///   - completion: Completion block called with the newly added `SessionRecord` on success; or an `Error` on failure
    public func addSessionAsync(
        id: SessionId,
        state: SessionState,
        startTime: Date,
        endTime: Date? = nil,
        crashReportId: String? = nil,
        completion: ((Result<SessionRecord, Error>) -> Void)?) {

        let session = SessionRecord(id: id, state: state, startTime: startTime, endTime: endTime, crashReportId: crashReportId)
        upsertSessionAsync(session, completion: completion)
    }

    /// Adds or updates a `SessionRecord` to the storage asynchronously.
    /// - Parameters:
    ///   - session: `SessionRecord` to insert
    ///   - completion: Completion block called with the newly added `SessionRecord` on success; or an `Error` on failure
    public func upsertSessionAsync(
        _ session: SessionRecord,
        completion: ((Result<SessionRecord, Error>) -> Void)?) {

        dbWriteAsync(block: { [weak self] db in
            try self?.upsertSession(db: db, session: session)
            return session
        }, completion: completion)
    }

    /// Fetches the stored session asynchronously with the given identifier, if any.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - completion: Completion block called with the fetched `SessionRecord?` on success; or an `Error` on failure
    public func fetchSessionAsync(
        id: SessionId,
        completion: @escaping (Result<SessionRecord?, Error>) -> Void) {

        dbFetchOneAsync(block: { [weak self] db in
            return try self?.fetchSession(db: db, id: id)
        }, completion: completion)
    }

    /// Updates the `endTime` of a stored session asynchronously.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - endTime: Date of when the session ended
    ///   - completion: Completion block called with the updated `SessionRecord?` on success; or an `Error` on failure
    public func updateSessionAsync(
        id: SessionId,
        endTime: Date,
        completion: @escaping (Result<SessionRecord?, Error>) -> Void) {

        fetchSessionAsync(id: id) { [weak self] result in
            switch result {
            case .success(let session):
                guard let session = session else {
                    completion(.success(nil))
                    return
                }

                self?.dbWriteAsync(block: { [weak self] db in
                    return try self?.updateSession(db: db, session: session, endTime: endTime)
                }, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Updates the `crashReportId` of a stored session asynchronously.
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - crashReportId: Identifier of the crash report linked with this session
    ///   - completion: Completion block called with the updated `SessionRecord?` on success; or an `Error` on failure
    public func updateSessionAsync(
        id: SessionId,
        crashReportId: String,
        completion: @escaping (Result<SessionRecord?, Error>) -> Void) {

        fetchSessionAsync(id: id) { [weak self] result in
            switch result {
            case .success(let session):
                guard let session = session else {
                    completion(.success(nil))
                    return
                }

                self?.dbWriteAsync(block: { [weak self] db in
                    return try self?.updateSession(db: db, session: session, crashReportId: crashReportId)
                }, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Returns how many finished sessions are stored asynchronously. A finished session is a session with a valid endTime.
    /// - Parameter completion: Completion block called with the count on success; or an `Error` on failure
    public func finishedSessionsCountAsync(completion: @escaping (Result<Int, Error>) -> Void) {
        dbFetchCountAsync(block: { [weak self] db in
            return try self?.finishedSessionsCount(db: db) ?? 0
        }, completion: completion)
    }

    /// Returns all the finished sessions in the storage asynchronously. A finished session is a session with a valid endTime.
    /// - Parameter completion: Completion block called with the fetched `[SessionRecord]` on success; or an `Error` on failure
    public func fetchFinishedSessionsAsync(completion: @escaping (Result<[SessionRecord], Error>) -> Void) {
        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchFinishedSessions(db: db) ?? []
        }, completion: completion)
    }

    /// Asynchronously returns the newest session in the storage, if any.
    /// - Parameter completion: Completion block called with the newest stored `SessionRecord?` on success; or an `Error` on failure
    public func fetchLatestSesssionAsync(completion: @escaping (Result<SessionRecord?, Error>) -> Void) {
        dbFetchOneAsync(block: { [weak self] db in
            return try self?.fetchLatestSessions(db: db)
        }, completion: completion)
    }
}

// MARK: - Database operations
fileprivate extension EmbraceStorage {
    func upsertSession(db: Database, session: SessionRecord) throws {
        try session.insert(db)
    }

    func fetchSession(db: Database, id: String) throws -> SessionRecord? {
        return try SessionRecord.fetchOne(db, key: id)
    }

    func updateSession(db: Database, session: SessionRecord?, endTime: Date) throws -> SessionRecord? {
        guard var session = session else {
            return nil
        }

        session.endTime = endTime
        try session.update(db)

        return session
    }

    func updateSession(db: Database, session: SessionRecord?, crashReportId: String) throws -> SessionRecord? {
        guard var session = session else {
            return nil
        }

        session.crashReportId = crashReportId
        try session.update(db)

        return session
    }

    func finishedSessionsRequest() -> QueryInterfaceRequest<SessionRecord> {
        return SessionRecord.filter(Column("end_time") != nil)
    }

    func finishedSessionsCount(db: Database) throws -> Int {
        return try finishedSessionsRequest().fetchCount(db)
    }

    func fetchFinishedSessions(db: Database) throws -> [SessionRecord] {
        return try finishedSessionsRequest().fetchAll(db)
    }

    func fetchLatestSessions(db: Database) throws -> SessionRecord? {
        return try SessionRecord
            .order(Column("start_time").desc)
            .fetchOne(db)
    }
}
