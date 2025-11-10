//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import XCTest

@testable import EmbraceStorageInternal

final class EmbraceStorage_SpanTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
    }

    func test_upsertSpan_appliesConfiguredLimitForType() throws {
        storage.options.spanLimits[.performance] = 3

        for i in 0..<3 {
            // given inserted record
            storage.upsertSpan(
                id: SpanId.random().hexString,
                name: "example \(i)",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )
        }

        storage.upsertSpan(
            id: SpanId.random().hexString,
            name: "newest",
            traceId: TraceId.random().hexString,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, 3)
        XCTAssertEqual(allRecords.map(\.name), ["example 1", "example 2", "newest"])
    }

    func test_upsertSpan_limitIsUniqueToSpecificType() throws {
        storage.options.spanLimits[.performance] = 3
        storage.options.spanLimits[.networkRequest] = 1

        // insert 3 .performance spans
        for i in 0..<3 {
            storage.upsertSpan(
                id: SpanId.random().hexString,
                name: "performance \(i)",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )
        }

        // insert 3 .networkHTTP spans
        for i in 0..<3 {
            storage.upsertSpan(
                id: SpanId.random().hexString,
                name: "network \(i)",
                traceId: TraceId.random().hexString,
                type: .networkRequest,
                data: Data(),
                startTime: Date()
            )
        }

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, 4)
        XCTAssertEqual(
            allRecords.map(\.name),
            [
                "performance 0",
                "performance 1",
                "performance 2",
                "network 2"
            ]
        )
    }

    func test_upsertSpan_appliesDefaultLimit() throws {

        let oldLimitDefault = storage.options.spanLimitDefault
        storage.options.spanLimitDefault = 3
        defer {
            storage.options.spanLimitDefault = oldLimitDefault
        }

        for i in 0..<(storage.options.spanLimitDefault + 1) {
            // given inserted record
            storage.upsertSpan(
                id: SpanId.random().hexString,
                name: "example \(i)",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )
        }

        storage.upsertSpan(
            id: SpanId.random().hexString,
            name: "newest",
            traceId: TraceId.random().hexString,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, storage.options.spanLimitDefault)
    }

    // MARK: - addEventsToSpan Tests

    func test_addEventsToSpan_addsEventsToExistingSpan() throws {
        // given a span in storage
        let spanId = SpanId.random().hexString
        let traceId = TraceId.random().hexString

        storage.upsertSpan(
            id: spanId,
            name: "test_span",
            traceId: traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when adding events to the span
        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: Date(),
            attributes: ["key1": "value1"]
        )
        let event2 = ImmutableSpanEventRecord(
            name: "event2",
            timestamp: Date(),
            attributes: ["key2": "value2"]
        )

        storage.addEventsToSpan(id: spanId, traceId: traceId, events: [event1, event2])

        // then the events are added to the span
        let fetchedSpan = storage.fetchSpan(id: spanId, traceId: traceId)
        XCTAssertNotNil(fetchedSpan)
        XCTAssertEqual(fetchedSpan?.events.count, 2)

        let events = fetchedSpan?.events ?? []
        XCTAssertEqual(events[0].name, "event1")
        XCTAssertEqual(events[0].attributes["key1"], "value1")
        XCTAssertEqual(events[1].name, "event2")
        XCTAssertEqual(events[1].attributes["key2"], "value2")
    }

    func test_addEventsToSpan_handlesEmptyEventsList() throws {
        // given a span in storage
        let spanId = SpanId.random().hexString
        let traceId = TraceId.random().hexString

        storage.upsertSpan(
            id: spanId,
            name: "test_span",
            traceId: traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when adding empty events list
        storage.addEventsToSpan(id: spanId, traceId: traceId, events: [])

        // then no events are added
        let fetchedSpan = storage.fetchSpan(id: spanId, traceId: traceId)
        XCTAssertNotNil(fetchedSpan)
        XCTAssertEqual(fetchedSpan?.events.count, 0)
    }

    func test_addEventsToSpan_handlesNonExistentSpan() throws {
        // given a non-existent span
        let spanId = SpanId.random().hexString
        let traceId = TraceId.random().hexString

        // when trying to add events to non-existent span
        let event = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: Date(),
            attributes: ["key1": "value1"]
        )

        storage.addEventsToSpan(id: spanId, traceId: traceId, events: [event])

        // then no crash occurs and span still doesn't exist
        let fetchedSpan = storage.fetchSpan(id: spanId, traceId: traceId)
        XCTAssertNil(fetchedSpan)
    }

    func test_addEventsToSpan_multipleCallsAccumulateEvents() throws {
        // given a span in storage
        let spanId = SpanId.random().hexString
        let traceId = TraceId.random().hexString

        storage.upsertSpan(
            id: spanId,
            name: "test_span",
            traceId: traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when adding events in multiple calls
        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: Date(),
            attributes: ["key1": "value1"]
        )
        storage.addEventsToSpan(id: spanId, traceId: traceId, events: [event1])

        let event2 = ImmutableSpanEventRecord(
            name: "event2",
            timestamp: Date(),
            attributes: ["key2": "value2"]
        )
        storage.addEventsToSpan(id: spanId, traceId: traceId, events: [event2])

        // then all events are accumulated
        let fetchedSpan = storage.fetchSpan(id: spanId, traceId: traceId)
        XCTAssertNotNil(fetchedSpan)
        XCTAssertEqual(fetchedSpan?.events.count, 2)
    }

    func test_addEventsToSpan_eventsAreSortedByTimestamp() throws {
        // given a span in storage
        let spanId = SpanId.random().hexString
        let traceId = TraceId.random().hexString

        storage.upsertSpan(
            id: spanId,
            name: "test_span",
            traceId: traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when adding events with different timestamps
        let now = Date()
        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: now.addingTimeInterval(200),
            attributes: ["key": "value1"]
        )
        let event2 = ImmutableSpanEventRecord(
            name: "event2",
            timestamp: now.addingTimeInterval(100),
            attributes: ["key": "value2"]
        )
        let event3 = ImmutableSpanEventRecord(
            name: "event3",
            timestamp: now.addingTimeInterval(300),
            attributes: ["key": "value3"]
        )

        storage.addEventsToSpan(id: spanId, traceId: traceId, events: [event1, event2, event3])

        // then events are sorted by timestamp when retrieved
        let fetchedSpan = storage.fetchSpan(id: spanId, traceId: traceId)
        XCTAssertNotNil(fetchedSpan)
        XCTAssertEqual(fetchedSpan?.events.count, 3)

        let events = fetchedSpan?.events ?? []
        XCTAssertEqual(events[0].name, "event2")
        XCTAssertEqual(events[1].name, "event1")
        XCTAssertEqual(events[2].name, "event3")
    }

}
