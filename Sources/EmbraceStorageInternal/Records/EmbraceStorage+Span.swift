//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceSemantics
import GRDB

extension EmbraceStorage {

    static let defaultSpanLimitByType = 1500

    /// Adds a span to the storage synchronously.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - name: name of the span
    ///   - traceId: Identifier of the trace containing this span
    ///   - type: SpanType of the span
    ///   - data: Data of the span
    ///   - startTime: Date of when the span started
    ///   - endTime: Date of when the span ended (optional)
    /// - Returns: The newly stored `SpanRecord`
    @discardableResult
    public func addSpan(
        id: String,
        name: String,
        traceId: String,
        type: SpanType,
        data: Data,
        startTime: Date,
        endTime: Date? = nil,
        processIdentifier: ProcessIdentifier = .current
    ) throws -> SpanRecord {

        let span = SpanRecord(
            id: id,
            name: name,
            traceId: traceId,
            type: type,
            data: data,
            startTime: startTime,
            endTime: endTime,
            processIdentifier: processIdentifier
        )
        try upsertSpan(span)

        return span
    }

    /// Adds or updates a `SpanRecord` to the storage synchronously.
    /// - Parameter record: `SpanRecord` to upsert
    public func upsertSpan(_ span: SpanRecord) throws {
        do {
            try dbQueue.write { [weak self] db in
                try self?.upsertSpan(db: db, span: span)
            }
        } catch let exception as DatabaseError {
            throw EmbraceStorageError.cannotUpsertSpan(
                spanName: span.name,
                message: exception.message ?? "[empty message]"
            )
        }
    }

    /// Fetches the stored `SpanRecord` synchronously with the given identifiers, if any.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    /// - Returns: The stored `SpanRecord`, if any
    public func fetchSpan(id: String, traceId: String) throws -> SpanRecord? {
        var span: SpanRecord?
        try dbQueue.read { db in
            span = try SpanRecord.fetchOne(
                db,
                key: [
                    SpanRecord.Schema.traceId.name: traceId,
                    SpanRecord.Schema.id.name: id
                ]
            )
        }

        return span
    }

    /// Synchonously removes all the closed spans older than the given date.
    /// If no date is provided, all closed spans will be removed.
    /// - Parameter date: Date used to determine which spans to remove
    public func cleanUpSpans(date: Date? = nil) throws {
        _ = try dbQueue.write { db in
            var filter = SpanRecord.filter(SpanRecord.Schema.endTime != nil)

            if let date = date {
                filter = filter.filter(SpanRecord.Schema.endTime < date)
            }

            try filter.deleteAll(db)
        }
    }

    /// Synchronously closes all open spans with the given `endTime`.
    /// - Parameters:
    ///   - endtime: Identifier of the trace containing this span
    public func closeOpenSpans(endTime: Date) throws {
        _ = try dbQueue.write { db in
            try SpanRecord
                .filter(
                    SpanRecord.Schema.endTime == nil &&
                    SpanRecord.Schema.processIdentifier != ProcessIdentifier.current
                )
                .updateAll(db, SpanRecord.Schema.endTime.set(to: endTime))
        }
    }

    /// Fetch spans for the given session record
    /// Will retrieve all spans that overlap with session record start / end (or last heartbeat)
    /// that occur within the same process. For cold start sessions, will include spans that occur before the session starts.
    /// Parameters:
    /// - sessionRecord: The session record to fetch spans for
    /// - ignoreSessionSpans: Whether to ignore the session's (or any other session's) own span
    public func fetchSpans(
        for sessionRecord: SessionRecord,
        ignoreSessionSpans: Bool = true,
        limit: Int = 1000
    ) throws -> [SpanRecord] {
        return try dbQueue.read { db in
            var query = SpanRecord.filter(for: sessionRecord)

            if ignoreSessionSpans {
                query = query.filter(SpanRecord.Schema.type != SpanType.session)
            }

            return try query
                .limit(limit)
                .fetchAll(db)
        }
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
        // default to 1500 if limit is not set
        let limit = options.spanLimits[span.type, default: Self.defaultSpanLimitByType]

        let count = try spanCount(db: db, type: span.type)
        if count >= limit {
            let spansToDelete = try fetchSpans(
                db: db,
                type: span.type,
                limit: count - limit + 1
            )

            for spanToDelete in spansToDelete {
                try spanToDelete.delete(db)
            }
        }

        try span.insert(db)
    }

    func requestSpans(of type: SpanType) -> QueryInterfaceRequest<SpanRecord> {
        return SpanRecord.filter(SpanRecord.Schema.type == type.rawValue)
    }

    func spanCount(db: Database, type: SpanType) throws -> Int {
        return try requestSpans(of: type)
            .fetchCount(db)
    }

    func fetchSpans(db: Database, type: SpanType, limit: Int?) throws -> [SpanRecord] {
        var request = requestSpans(of: type)
            .order(SpanRecord.Schema.startTime)

        if let limit = limit {
            request = request.limit(limit)
        }

        return try request.fetchAll(db)
    }

    func spanInTimeFrameByTypeRequest(
        startTime: Date,
        endTime: Date,
        includeOlder: Bool,
        ignoreSessionSpans: Bool
    ) -> QueryInterfaceRequest<SpanRecord> {

        // end_time is nil
        // or end_time is between parameters (start_time, end_time)
        var filter = SpanRecord.filter(
            SpanRecord.Schema.endTime == nil ||
            (SpanRecord.Schema.endTime <= endTime && SpanRecord.Schema.endTime >= startTime)
        )

        // if we don't include old spans
        // select where start_time is greater than parameter (start_time)
        if includeOlder == false {
            filter = filter.filter(SpanRecord.Schema.startTime >= startTime)
        }

        // if ignoring session span
        // select where type is not session span
        if ignoreSessionSpans == true {
            filter = filter.filter(SpanRecord.Schema.type != SpanType.session.rawValue)
        }

        return filter
    }

    func fetchSpans(
        db: Database,
        startTime: Date,
        endTime: Date,
        includeOlder: Bool,
        ignoreSessionSpans: Bool,
        limit: Int?
    ) throws -> [SpanRecord] {

        var request = spanInTimeFrameByTypeRequest(
            startTime: startTime,
            endTime: endTime,
            includeOlder: includeOlder,
            ignoreSessionSpans: ignoreSessionSpans
        ).order(SpanRecord.Schema.startTime)

        if let limit = limit {
            request = request.limit(limit)
        }

        return try request.fetchAll(db)
    }
}
