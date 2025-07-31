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
    ///   - processId: Identifier of the process in which this span was created
    ///   - sessionId: Identifier of the session containing this span (optional)
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
        processId: ProcessIdentifier = .current,
        sessionId: SessionIdentifier? = nil
    ) -> EmbraceSpan? {

        // update existing?
        if let span = updateExistingSpan(
            id: id,
            name: name,
            traceId: traceId,
            type: type,
            data: data,
            startTime: startTime,
            endTime: endTime,
            processId: processId,
            sessionId: sessionId
        ) {
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
            processId: processId,
            sessionId: sessionId
        ) {
            coreData.save()
            return span
        }

        return nil
    }

    func fetchSpanRequest(id: String, traceId: String) -> NSFetchRequest<SpanRecord> {
        let request = SpanRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@ AND traceId == %@", id, traceId)

        return request
    }

    func updateExistingSpan(
        id: String,
        name: String,
        traceId: String,
        type: SpanType,
        data: Data,
        startTime: Date,
        endTime: Date? = nil,
        processId: ProcessIdentifier = .current,
        sessionId: SessionIdentifier? = nil
    ) -> EmbraceSpan? {
        var result: EmbraceSpan?

        let request = fetchSpanRequest(id: id, traceId: traceId)
        coreData.fetchFirstAndPerform(withRequest: request) { span in
            guard let span else { return }

            // prevent modifications on closed spans!
            if span.endTime == nil {
                span.name = name
                span.typeRaw = type.rawValue
                span.data = data
                span.startTime = startTime
                span.endTime = endTime
                span.processIdRaw = processId.hex
                span.sessionIdRaw = sessionId?.toString
                coreData.save()
            }

            result = span.toImmutable()
        }

        return result
    }

    /// Ends the stored `SpanRecord` asynchronously with the given identifiers and end time.
    /// Should only be used for sessions!
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    public func endSpan(id: String, traceId: String, endTime: Date) {
        coreData.performAsyncOperation { [self] _ in
            let request = fetchSpanRequest(id: id, traceId: traceId)
            guard let span = coreData.fetch(withRequest: request).first else {
                return
            }
            if span.endTime == nil {
                span.endTime = endTime
                coreData.save()
            }
        }
    }

    /// Fetches the stored `SpanRecord` synchronously with the given identifiers, if any.
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Identifier of the trace containing this span
    /// - Returns: Immutable copy of rhe stored `SpanRecord`, if any
    public func fetchSpan(id: String, traceId: String) -> EmbraceSpan? {

        // fetch
        let request = fetchSpanRequest(id: id, traceId: traceId)
        var result: EmbraceSpan?

        coreData.fetchFirstAndPerform(withRequest: request) { record in
            // convert to immutable struct
            result = record?.toImmutable()
        }
        return result
    }

    /// Synchronously removes all the closed spans older than the given date.
    /// If no date is provided, all closed spans that are not from the current process
    /// will be removed.
    /// - Parameter date: Date used to determine which spans to remove
    public func cleanUpSpans(date: Date? = nil) {
        let request = SpanRecord.createFetchRequest()

        if let date = date {
            request.predicate = NSPredicate(format: "endTime != nil AND endTime < %@", date as NSDate)
        } else {
            request.predicate = NSPredicate(
                format: "endTime != nil AND processIdRaw != %@",
                ProcessIdentifier.current.hex)
        }

        coreData.deleteRecords(withRequest: request)
    }

    /// Synchronously closes all open spans from previous processes with the given `endTime`.
    /// - Parameters:
    ///   - endTime: Identifier of the trace containing this span
    public func closeOpenSpans(endTime: Date) {

        let request = SpanRecord.createFetchRequest()
        request.predicate = NSPredicate(
            format: "endTime = nil AND processIdRaw != %@",
            ProcessIdentifier.current.hex
        )

        coreData.fetchAndPerform(withRequest: request) { [self] spans in
            for span in spans {
                span.endTime = endTime
            }
            coreData.save()
        }
    }

    /// Fetch spans for the given session record
    /// Will retrieve all spans that overlap with session record start / end (or last heartbeat)
    /// that occur within the same process. For cold start sessions, will include spans that occur before the session starts.
    /// - Parameters:
    ///   - session: The session record to fetch spans for
    ///   - ignoreSessionSpans: Whether to ignore the session's (or any other session's) own span
    ///   - limit: Limit of the amount of spans to be retrieved
    /// - Returns: Array containing the immutable copies of the spans.
    public func fetchSpans(
        for session: EmbraceSession,
        ignoreSessionSpans: Bool = true
    ) -> [EmbraceSpan] {

        let request = SpanRecord.createFetchRequest()
        request.fetchLimit = jsonSpansLimit

        let endTime = (session.endTime ?? session.lastHeartbeatTime) as NSDate

        var predicate: NSPredicate

        // special case for cold start sessions
        // we grab spans that might have started before the session but within the same process
        if session.coldStart {
            predicate = NSPredicate(
                format: "processIdRaw == %@ AND startTime <= %@",
                session.processIdRaw,
                endTime
            )
        }

        // otherwise we check if the span is within the boundaries of the session
        else {
            let startTime = session.startTime as NSDate

            // span matches session id
            let sessionPredicate = NSPredicate(
                format: "sessionIdRaw != nil AND sessionIdRaw == %@",
                session.idRaw
            )

            // span starts within session
            let predicate1 = NSPredicate(
                format: "startTime >= %@ AND startTime <= %@",
                startTime,
                endTime
            )

            // span starts before session and doesn't end before session starts
            let predicate2 = NSPredicate(
                format: "startTime < %@ AND (endTime = nil OR endTime >= %@)",
                startTime,
                startTime
            )

            predicate = NSCompoundPredicate(type: .or, subpredicates: [sessionPredicate, predicate1, predicate2])
        }

        // ignore session spans?
        if ignoreSessionSpans {
            let sessionTypePredicate = NSPredicate(format: "typeRaw != %@", SpanType.session.rawValue)
            request.predicate = NSCompoundPredicate(type: .and, subpredicates: [sessionTypePredicate, predicate])
        } else {
            request.predicate = predicate
        }

        // fetch
        var result: [EmbraceSpan] = []
        coreData.fetchAndPerform(withRequest: request) { records in
            // convert to immutable struct
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }
}

// MARK: - Database operations
extension EmbraceStorage {
    func limitByType(_ type: SpanType) -> Int {
        switch type.primary {
        case .performance,
            .system,
            .ux:
            return 1500
        }
    }

    var jsonSpansLimit: Int {
        var total = 0
        PrimaryType.allCases.forEach {
            total += limitByType(SpanType(primary: $0))
        }
        return total
    }

    fileprivate func removeOldSpanIfNeeded(forType type: SpanType) {
        // check limit and delete if necessary
        // default to 1500 if limit is not set
        let limit = options.spanLimits[type, default: limitByType(type)]

        let request = SpanRecord.createFetchRequest()
        request.predicate = NSPredicate(format: "typeRaw BEGINSWITH %@", type.rawValue)
        let count = coreData.count(withRequest: request)

        if count >= limit {
            request.fetchLimit = count - limit + 1
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

            coreData.deleteRecords(withRequest: request)
        }
    }
}
