//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

// MARK: - Sync span operations
extension EmbraceStorage {

    /// Adds a span to the storage synchronously.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - data: Data of the span
    ///   - startTime: Date of when the span started
    ///   - endTime: Date of when the span ended (optional)
    /// - Returns: The newly stored `SpanRecord`
    public func addSpan(id: String, traceId: String, type: SpanType, data: Data, startTime: Date, endTime: Date? = nil) throws -> SpanRecord {
        let span = SpanRecord(id: id, traceId: traceId, type: type, data: data, startTime: startTime, endTime: endTime)
        try upsertSpan(span)

        return span
    }

    /// Adds or updates a `SpanRecord` to the storage synchronously.
    /// - Parameter record: `SpanRecord` to upsert
    public func upsertSpan(_ span: SpanRecord) throws {
        try dbQueue.write { [weak self] db in
            try self?.upsertSpan(db: db, span: span)
        }
    }

    /// Fetches the stored `SpanRecord` synchronously with the given identifiers, if any.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    /// - Returns: The stored `SpanRecord`, if any
    public func fetchSpan(id: String, traceId: String) throws -> SpanRecord? {
        var span: SpanRecord?
        try dbQueue.read { [weak self] db in
            span = try self?.fetchSpan(db: db, id: id, traceId: traceId)
        }

        return span
    }

    /// Fetches all the stored spans synchronously with a given trace identifier.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    /// - Returns: Array containing the stored `SpanRecords`
    public func fetchSpans(traceId: String) throws -> [SpanRecord] {
        var spans: [SpanRecord] = []
        try dbQueue.read { [weak self] db in
            spans = try self?.fetchSpans(db: db, traceId: traceId) ?? []
        }

        return spans
    }

    /// Fetches all the stored open spans synchronously with a given trace identifier. An open span is a span without an `endTime`.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: Type of span to fetch (optional)
    /// - Returns: Array containing the stored `SpanRecords`
    public func fetchOpenSpans(traceId: String, type: SpanType? = nil) throws -> [SpanRecord] {
        var spans: [SpanRecord] = []
        try dbQueue.read { [weak self] db in
            spans = try self?.fetchOpenSpans(db: db, traceId: traceId, type: type) ?? []
        }

        return spans
    }

    /// Synchronously returns how many spans with a given trace identifier and type are stored.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    /// - Returns: Int containing the amount of spans
    public func spanCount(traceId: String, type: SpanType) throws -> Int {
        var count = 0
        try dbQueue.read { [weak self] db in
            count = try self?.spanCount(db: db, traceId: traceId, type: type) ?? 0
        }

        return count
    }

    /// Fetches all the stored spans synchronously with a given trace identifier and type.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - limit: Limit the amount of spans fetched (optional)
    /// - Returns: Array containing the stored `SpanRecords`
    public func fetchSpans(traceId: String, type: SpanType, limit: Int? = nil) throws -> [SpanRecord] {
        var spans: [SpanRecord] = []
        try dbQueue.read { [weak self] db in
            spans = try self?.fetchSpans(db: db, traceId: traceId, type: type, limit: limit) ?? []
        }

        return spans
    }

    /// Synchronously returns how many spans of the given type that started atfter a certain time are stored.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    /// - Returns: Int containing the amount of spans
    public func spanCount(startTime: Date, type: SpanType) throws -> Int {
        var count = 0
        try dbQueue.read { [weak self] db in
            count = try self?.spanCount(db: db, startTime: startTime, type: type) ?? 0
        }

        return count
    }

    /// Fetches all the stored spans synchronously that started after a certain time.
    /// - Parameters:
    ///   - startTime: Date to be used as `startTime` for the fetch
    ///   - type: SpanType of the span
    ///   - limit: Limit the amount of spans fetched (optional)
    /// - Returns: Array containing the stored `SpanRecords`
    public func fetchSpans(startTime: Date, type: SpanType, limit: Int? = nil) throws -> [SpanRecord] {
        var spans: [SpanRecord] = []
        try dbQueue.read { [weak self] db in
            spans = try self?.fetchSpans(db: db, startTime: startTime, type: type, limit: limit) ?? []
        }

        return spans
    }
}

// MARK: - Async span operations
extension EmbraceStorage {

    /// Adds a span to the storage asynchronously.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - data: Data of the span
    ///   - startTime: Date of when the span started
    ///   - endTime: Date of when the span ended (optional)
    ///   - completion: Completion block called with the newly added `SpanRecord` on success; or an `Error` on failure
    public func addSpanAsync(
        id: String,
        traceId: String,
        type: SpanType,
        data: Data,
        startTime: Date,
        endTime: Date? = nil,
        completion: ((Result<SpanRecord, Error>) -> Void)?) {

        let span = SpanRecord(id: id, traceId: traceId, type: type, data: data, startTime: startTime, endTime: endTime)
        upsertSpanAsync(span, completion: completion)
    }

    /// Adds or updates a `SpanRecord` to the storage asynchronously.
    /// - Parameters:
    ///   - span: `SpanRecord` to insert
    ///   - completion: Completion block called with the newly added `SpanRecord` on success; or an `Error` on failure
    public func upsertSpanAsync(
        _ span: SpanRecord,
        completion: ((Result<SpanRecord, Error>) -> Void)?) {

        dbWriteAsync(block: { [weak self] db in
            try self?.upsertSpan(db: db, span: span)
            return span
        }, completion: completion)
    }

    /// Fetches the stored `SpanRecord` asynchronously with the given identifiers, if any.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    ///   - completion: Completion block called with the fetched`SpanRecord?` on success; or an `Error` on failure
    /// - Returns: The stored `SpanRecord`, if any
    public func fetchSpanAsync(
        id: String,
        traceId: String,
        completion: @escaping (Result<SpanRecord?, Error>) -> Void) {

        dbFetchOneAsync(block: { [weak self] db in
            return try self?.fetchSpan(db: db, id: id, traceId: traceId)
        }, completion: completion)
    }

    /// Fetches all the stored spans asynchronously with a given trace identifier.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - completion: Completion block called with the fetched `[SpanRecord]` on success; or an `Error` on failure
    public func fetchSpansAsync(
        traceId: String,
        completion: @escaping (Result<[SpanRecord], Error>) -> Void) {

        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchSpans(db: db, traceId: traceId) ?? []
        }, completion: completion)
    }

    /// Fetches all the stored open spans asynchronously with a given trace identifier. An open span is a span without an `endTime`.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of span to fetch (optional)
    ///   - completion: Completion block called with the fetched `[SpanRecord]` on success; or an `Error` on failure
    public func fetchOpenSpansAsync(
        traceId: String,
        type: SpanType? = nil,
        completion: @escaping (Result<[SpanRecord], Error>) -> Void) {

        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchOpenSpans(db: db, traceId: traceId, type: type) ?? []
        }, completion: completion)
    }

    /// Asynchronously returns how many spans with a given trace identifier and type are stored.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - completion: Completion block called with the count on success; or an `Error` on failure
    public func spanCountAsync(
        traceId: String,
        type: SpanType,
        completion: @escaping (Result<Int, Error>) -> Void) {

        dbFetchCountAsync(block: { [weak self] db in
            return try self?.spanCount(db: db, traceId: traceId, type: type) ?? 0
        }, completion: completion)
    }

    /// Fetches all the stored spans asynchronously with a given trace identifier and type.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - limit: Limit the amount of spans fetched (optional)
    ///   - completion: Completion block called with the fetched `[SpanRecord]` on success; or an `Error` on failure
    public func fetchSpansAsync(
        traceId: String,
        type: SpanType,
        limit: Int? = nil,
        completion: @escaping (Result<[SpanRecord], Error>) -> Void) {

        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchSpans(db: db, traceId: traceId, type: type, limit: limit) ?? []
        }, completion: completion)
    }

    /// Asynchronously returns how many spans of the given type that started atfter a certain time are stored.
    /// - Parameters:
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - completion: Completion block called with the count on success; or an `Error` on failure
    public func spanCountAsync(
        startTime: Date,
        type: SpanType,
        completion: @escaping (Result<Int, Error>) -> Void) {

        dbFetchCountAsync(block: { [weak self] db in
            return try self?.spanCount(db: db, startTime: startTime, type: type) ?? 0
        }, completion: completion)
    }

    /// Fetches all the stored spans asynchronously that started after a certain time.
    /// - Parameters:
    ///   - startTime: Date to be used as `startTime` for the fetch
    ///   - type: SpanType of the span
    ///   - limit: Limit the amount of spans fetched (optional)
    ///   - completion: Completion block called with the fetched `[SpanRecord]` on success; or an `Error` on failure
    public func fetchSpansAsync(
        startTime: Date,
        type: SpanType,
        limit: Int? = nil,
        completion: @escaping (Result<[SpanRecord], Error>) -> Void) {

        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchSpans(db: db, startTime: startTime, type: type, limit: limit) ?? []
        }, completion: completion)
    }
}

// MARK: - Database operations
fileprivate extension EmbraceStorage {
    func upsertSpan(db: Database, span: SpanRecord) throws {
        // update if its already stored
        if try span.exists(db) {
            try span.update(db)
            return
        }

        // check limit and delete if necessary
        if let limit = options.spanLimits[span.type.rawValue] {

            let count = try spanCount(traceId: span.traceId, type: span.type)
            if count >= limit {
                let spansToDelete = try fetchSpans(traceId: span.traceId, type: span.type, limit: count - limit + 1)

                for spanToDelete in spansToDelete {
                    try spanToDelete.delete(db)
                }
            }
        }

        try span.insert(db)
    }

    func fetchSpan(db: Database, id: String, traceId: String) throws -> SpanRecord? {
        return try SpanRecord.fetchOne(db, key: ["trace_id": traceId, "id": id])
    }

    func fetchSpans(db: Database, traceId: String) throws -> [SpanRecord] {
        return try SpanRecord
            .filter(Column("trace_id") == traceId)
            .order(Column("start_time"))
            .fetchAll(db)
    }

    func fetchOpenSpans(db: Database, traceId: String, type: SpanType? = nil) throws -> [SpanRecord] {
        if let type = type {
            return try SpanRecord
                .filter(Column("trace_id") == traceId && Column("end_time") == nil && Column("type") == type.rawValue)
                .order(Column("start_time"))
                .fetchAll(db)
        }

        return try SpanRecord
            .filter(Column("trace_id") == traceId && Column("end_time") == nil)
            .order(Column("start_time"))
            .fetchAll(db)
    }

    func spanInTraceByTypeRequest(traceId: String, type: SpanType) -> QueryInterfaceRequest<SpanRecord> {
        return SpanRecord.filter(Column("trace_id") == traceId && Column("type") == type.rawValue)
    }

    func spanCount(db: Database, traceId: String, type: SpanType) throws -> Int {
        return try spanInTraceByTypeRequest(traceId: traceId, type: type).fetchCount(db)
    }

    func fetchSpans(db: Database, traceId: String, type: SpanType, limit: Int?) throws -> [SpanRecord] {
        var request = spanInTraceByTypeRequest(traceId: traceId, type: type).order(Column("start_time"))

        if let limit = limit {
            request = request.limit(limit)
        }

        return try request.fetchAll(db)
    }

    func spanAfterTimeByTypeRequest(startTime: Date, type: SpanType) -> QueryInterfaceRequest<SpanRecord> {
        return SpanRecord.filter(Column("start_time") >= startTime && Column("type") == type.rawValue)
    }

    func spanCount(db: Database, startTime: Date, type: SpanType) throws -> Int {
        return try spanAfterTimeByTypeRequest(startTime: startTime, type: type).fetchCount(db)
    }

    func fetchSpans(db: Database, startTime: Date, type: SpanType, limit: Int?) throws -> [SpanRecord] {
        var request = spanAfterTimeByTypeRequest(startTime: startTime, type: type).order(Column("start_time"))

        if let limit = limit {
            request = request.limit(limit)
        }

        return try request.fetchAll(db)
    }
}
