//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
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
        endTime: Date? = nil
    ) throws -> SpanRecord {

        let span = SpanRecord(
            id: id,
            name: name,
            traceId: traceId,
            type: type,
            data: data,
            startTime: startTime,
            endTime: endTime
        )
        try upsertSpan(span)

        return span
    }

    /// Adds or updates a `SpanRecord` to the storage synchronously.
    /// - Parameter record: `SpanRecord` to upsert
    public func upsertSpan(_ span: SpanRecord) throws {
        try dbQueue.write { [weak self] db in
            do {
                try self?.upsertSpan(db: db, span: span)
            } catch let e as DatabaseError {
                logger.error("Failed upsertSpan `\(span.name)`: \(e.message ?? "[empty message]")")
            }
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
                .filter(SpanRecord.Schema.endTime == nil)
                .updateAll(db, SpanRecord.Schema.endTime.set(to: endTime))
        }
    }

    /// Fetches all the stored spans synchronously that started in a given time frame.
    /// - Parameters:
    ///   - startTime: Date to be used as `startTime` for the fetch
    ///   - endTime: Date to be used as `endTime` for the fetch
    ///   - includeOlder: Defines if spans that were started before the given `startTime` should be included.
    ///   - limit: Limit the amount of spans fetched (optional)
    /// - Returns: Array containing the stored `SpanRecords`
    public func fetchSpans(
        startTime: Date,
        endTime: Date,
        includeOlder: Bool = true,
        ignoreSessionSpans: Bool = true,
        limit: Int? = nil
    ) throws -> [SpanRecord] {

        var spans: [SpanRecord] = []
        try dbQueue.read { [weak self] db in
            spans = try self?.fetchSpans(
                db: db,
                startTime: startTime,
                endTime: endTime,
                includeOlder: includeOlder,
                ignoreSessionSpans: ignoreSessionSpans,
                limit: limit
            ) ?? []
        }

        return spans
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

        var filter = SpanRecord.filter(
            SpanRecord.Schema.endTime == nil ||
            (SpanRecord.Schema.endTime <= endTime && SpanRecord.Schema.endTime >= startTime)
        )

        if includeOlder == false {
            filter = filter.filter(SpanRecord.Schema.startTime >= startTime)
        }

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
