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

    /// Adds or updates a span to the storage synchronously.
    public func upsertSpan(_ span: EmbraceSpan, onlyUpdate: Bool = false) {

        // update existing?
        if updateExistingSpan(span) {
            return
        }

        // check if we can add a new span
        guard !onlyUpdate else {
            return
        }

        // make space if needed
        removeOldSpanIfNeeded(forType: span.type)

        // add new
        SpanRecord.create(context: coreData.context, span: span)
        coreData.save()
    }

    func fetchSpanRequest(id: String, traceId: String) -> NSFetchRequest<SpanRecord> {
        let request = SpanRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@ AND traceId == %@", id, traceId)

        return request
    }

    func updateExistingSpan(_ span: EmbraceSpan) -> Bool {

        var result = false
        let request = fetchSpanRequest(id: span.context.spanId, traceId: span.context.traceId)

        coreData.fetchFirstAndPerform(withRequest: request) { record, context in
            guard let record else { return }

            // prevent modifications on closed spans!
            if record.endTime == nil {
                record.name = span.name
                record.parentSpanId = span.parentSpanId
                record.typeRaw = span.type.rawValue
                record.statusRaw = span.status.rawValue
                record.startTime = span.startTime
                record.endTime = span.endTime
                record.processIdRaw = span.processId.stringValue
                record.sessionIdRaw = span.sessionId?.stringValue
                record.attributes = span.attributes.keyValueEncoded()

                self.updateEvents(span: record, events: span.events, context: context)
                self.updateLinks(span: record, links: span.links, context: context)

                coreData.save()
            }

            result = true
        }

        return result
    }

    /// Updates the events for a given span.
    /// Adds new SpanEventRecords as needed.
    private func updateEvents(span: SpanRecord, events: [EmbraceSpanEvent], context: NSManagedObjectContext) {

        // events can only be added so we don't need to do anything
        // if the passed events count is not bigger than the current count
        guard events.count > span.events.count else {
            return
        }

        var i = 0

        // update already created records without caring about order
        for storedEvent in span.events {
            let event = events[i]

            storedEvent.update(
                name: event.name,
                timestamp: event.timestamp,
                attributes: event.attributes
            )

            i += 1
        }

        // add new records if needed
        for j in i..<events.count {
            let event = events[j]

            if let record = SpanEventRecord.create(
                context: context,
                event: event,
                span: span
            ) {
                span.events.insert(record)
            }
        }
    }

    /// Updates the links for a given span.
    /// Adds new SpanEventLinks as needed.
    private func updateLinks(span: SpanRecord, links: [EmbraceSpanLink], context: NSManagedObjectContext) {

        // links can only be added so we don't need to do anything
        // if the passed links count is not bigger than the current count
        guard links.count > span.links.count else {
            return
        }

        var i = 0

        // update already created records without caring about order
        for storedLink in span.links {
            let link = links[i]

            storedLink.update(
                spanId: link.context.spanId,
                traceId: link.context.traceId,
                attributes: link.attributes
            )

            i += 1
        }

        // add new records if needed
        for j in i..<links.count {
            let link = links[j]

            if let record = SpanLinkRecord.create(
                context: context,
                link: link,
                span: span
            ) {
                span.links.insert(record)
            }
        }
    }

    /// Asynchronously updates the status of the stored span for the given identifiers
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Trace identifier of the span
    ///   - status: New span status
    public func setSpanStatus(id: String, traceId: String, status: EmbraceSpanStatus) {
        coreData.performAsyncOperation(save: true) { context in
            do {
                let request = self.fetchSpanRequest(id: id, traceId: traceId)
                if let span = try context.fetch(request).first {
                    span.statusRaw = status.rawValue
                }
            } catch {}
        }
    }

    /// Asynchronously updates the attributes of the stored span for the given identifiers
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Trace identifier of the span
    ///   - attributes: New span attributes
    public func setSpanAttributes(id: String, traceId: String, attributes: EmbraceAttributes) {
        coreData.performAsyncOperation(save: true) { context in
            do {
                let request = self.fetchSpanRequest(id: id, traceId: traceId)
                if let span = try context.fetch(request).first {
                    span.attributes = attributes.keyValueEncoded()
                }
            } catch {}
        }
    }

    /// Asynchrnously adds a new event o the stored span for the given identifiers
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Trace identifier of the span
    ///   - event: Span event to add
    public func addSpanEvent(id: String, traceId: String, event: EmbraceSpanEvent) {
        coreData.performAsyncOperation(save: true) { context in
            do {
                let request = self.fetchSpanRequest(id: id, traceId: traceId)
                if let span = try context.fetch(request).first {
                    if let record = SpanEventRecord.create(
                        context: context,
                        event: event,
                        span: span
                    ) {
                        span.events.insert(record)
                    }
                }
            } catch {}
        }
    }

    /// Asynchrnously adds a new link o the stored span for the given identifiers
    /// - Parameters:
    ///   - id: Identifier of the span
    ///   - traceId: Trace identifier of the span
    ///   - link: Span link to add
    public func addSpanLink(id: String, traceId: String, link: EmbraceSpanLink) {
        coreData.performAsyncOperation(save: true) { context in
            do {
                let request = self.fetchSpanRequest(id: id, traceId: traceId)
                if let span = try context.fetch(request).first {
                    if let record = SpanLinkRecord.create(
                        context: context,
                        link: link,
                        span: span
                    ) {
                        span.links.insert(record)
                    }
                }
            } catch {}
        }
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

        coreData.fetchFirstAndPerform(withRequest: request) { record, _ in
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
                ProcessIdentifier.current.stringValue)
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
            ProcessIdentifier.current.stringValue
        )

        coreData.fetchAndPerform(withRequest: request) { [self] spans, _ in
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
                session.processId.stringValue,
                endTime
            )
        }

        // otherwise we check if the span is within the boundaries of the session
        else {
            let startTime = session.startTime as NSDate

            // span matches session id
            let sessionPredicate = NSPredicate(
                format: "sessionIdRaw != nil AND sessionIdRaw == %@",
                session.id.stringValue
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
            let sessionTypePredicate = NSPredicate(format: "typeRaw != %@", EmbraceType.session.rawValue)
            request.predicate = NSCompoundPredicate(type: .and, subpredicates: [sessionTypePredicate, predicate])
        } else {
            request.predicate = predicate
        }

        // fetch
        var result: [EmbraceSpan] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in
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
    func limitByType(_ type: EmbraceType) -> Int {
        switch type.primary {
        case .performance,
            .system,
            .ux:
            return options.spanLimitDefault
        }
    }

    var jsonSpansLimit: Int {
        var total = 0
        PrimaryType.allCases.forEach {
            total += limitByType(EmbraceType(primary: $0))
        }
        return total
    }

    fileprivate func removeOldSpanIfNeeded(forType type: EmbraceType) {
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
