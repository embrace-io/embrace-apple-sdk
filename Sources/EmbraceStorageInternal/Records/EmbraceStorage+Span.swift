//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceSemantics
import CoreData

extension EmbraceStorage {

    static let defaultSpanLimitByType = 1500

    /// Adds or updates a span to the storage synchronously.
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
    public func upsertSpan(
        id: String,
        name: String,
        traceId: String,
        type: SpanType,
        data: Data,
        startTime: Date,
        endTime: Date? = nil,
        processId: ProcessIdentifier = .current
    ) -> SpanRecord? {

        // update existing?
        if let span = fetchSpan(id: id, traceId: traceId) {
            
            // prevent modifications on closed spans!
            guard span.endTime == nil else {
                return span
            }

            span.name = name
            span.typeRaw = type.rawValue
            span.data = data
            span.startTime = startTime
            span.endTime = endTime
            span.processIdRaw = processId.hex

            coreData.save()
            return span
        }

        // make space if needed
        removeOldSpanIfNeeded(forType: type)

        // add new
        if let span = SpanRecord.create(
            context: coreData.context,
            id: id,
            name: name,
            traceId: traceId,
            type: type,
            data: data,
            startTime: startTime,
            endTime: endTime,
            processId: processId
        ) {
            coreData.save()
            return span
        }

        return nil
    }

    /// Fetches the stored `SpanRecord` synchronously with the given identifiers, if any.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    /// - Returns: The stored `SpanRecord`, if any
    public func fetchSpan(id: String, traceId: String) -> SpanRecord? {
        let request = SpanRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@ AND traceId == %@", id, traceId)

        return coreData.fetch(withRequest: request).first
    }

    /// Synchronously removes all the closed spans older than the given date.
    /// If no date is provided, all closed spans will be removed.
    /// - Parameter date: Date used to determine which spans to remove
    public func cleanUpSpans(date: Date? = nil) {
        let request = SpanRecord.createFetchRequest()

        if let date = date {
            request.predicate = NSPredicate(format: "endTime != nil AND endTime < %@", date as NSDate)
        } else {
            request.predicate = NSPredicate(format: "endTime != nil")
        }

        let spans = coreData.fetch(withRequest: request)
        coreData.deleteRecords(spans)
    }

    /// Synchronously closes all open spans with the given `endTime`.
    /// - Parameters:
    ///   - endTime: Identifier of the trace containing this span
    public func closeOpenSpans(endTime: Date) {
        let request = SpanRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "endTime = nil")

        let spans = coreData.fetch(withRequest: request)

        for span in spans {
            span.endTime = endTime
        }

        coreData.save()
    }

    /// Fetch spans for the given session record
    /// Will retrieve all spans that overlap with session record start / end (or last heartbeat)
    /// that occur within the same process. For cold start sessions, will include spans that occur before the session starts.
    /// Parameters:
    /// - session: The session record to fetch spans for
    /// - ignoreSessionSpans: Whether to ignore the session's (or any other session's) own span
    public func fetchSpans(
        for session: EmbraceSession,
        ignoreSessionSpans: Bool = true,
        limit: Int = 1000
    ) -> [SpanRecord] {

        let request = SpanRecord.createFetchRequest()
        request.fetchLimit = limit

        let endTime = (session.endTime ?? session.lastHeartbeatTime) as NSDate

        // special case for cold start sessions
        // we grab spans that might have started before the session but within the same process
        if session.coldStart {
            request.predicate = NSPredicate(
                format: "processIdRaw == %@ AND startTime <= %@",
                session.processIdRaw,
                endTime
            )
        }

        // otherwise we check if the span is within the boundaries of the session
        else {
            let startTime = session.startTime as NSDate

            // span starts within session and
            //   - ends before session ends or
            //   - hasn't ended yet
            let predicate1 = NSPredicate(
                format: "startTime >= %@ AND (endTime = nil OR endTime <= %@)",
                startTime,
                endTime
            )

            // span starts before session and
            //   - ends within session or
            //   - hasn't ended yet
            let predicate2 = NSPredicate(
                format: "startTime < %@ AND (endTime = nil OR (endTime >= %@ AND endTime <= %@))",
                startTime,
                startTime,
                endTime
            )

            request.predicate = NSCompoundPredicate(type: .or, subpredicates: [predicate1, predicate2])
        }

        return coreData.fetch(withRequest: request)
    }
}

// MARK: - Database operations
fileprivate extension EmbraceStorage {
    func removeOldSpanIfNeeded(forType type: SpanType) {
        // check limit and delete if necessary
        // default to 1500 if limit is not set
        let limit = options.spanLimits[type, default: Self.defaultSpanLimitByType]

        let request = SpanRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "typeRaw == %@", type.rawValue)
        let count = coreData.count(withRequest: request)

        if count >= limit {
            request.fetchLimit = count - limit + 1
            request.sortDescriptors = [ NSSortDescriptor(key: "startTime", ascending: true) ]

            let spansToDelete = coreData.fetch(withRequest: request)
            coreData.deleteRecords(spansToDelete)
        }
    }
}
