//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceStorageInternal

class SpanRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

    func test_upsertSpan() throws {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // then span should exist in storage
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
    }

    func test_endSpan() throws {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when ending the span
        storage.endSpan(id: "id", traceId: "traceId", endTime: Date())

        // then span should be updated correctly
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
        XCTAssertNotNil(spans[0].endTime)
    }

    func test_endSpan_alreadyEnded() throws {
        // given inserted span with an end time
        let originalDate = Date(timeIntervalSince1970: 1)
        storage.upsertSpan(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date(),
            endTime: originalDate
        )

        // when attempting to end the span again
        let date = Date(timeIntervalSince1970: 123)
        storage.endSpan(id: "id", traceId: "traceId", endTime: date)

        // then span should not be updated
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
        XCTAssertEqual(spans[0].endTime!.timeIntervalSince1970, originalDate.timeIntervalSince1970, accuracy: 0.01)
    }

    func test_fetchSpan() throws {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            name: "a name",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(),
            endTime: nil
        )

        // when fetching the span
        let span = storage.fetchSpan(id: "id", traceId: TestConstants.traceId)

        // then the span should be valid
        XCTAssertNotNil(span)
        XCTAssertEqual(span!.id, "id")
        XCTAssertEqual(span!.traceId, TestConstants.traceId)
        XCTAssertEqual(span!.name, "a name")
        XCTAssertEqual(span!.type, .performance)
        XCTAssertNil(span!.endTime)
    }

    func test_cleanUpSpans() throws {
        // given inserted spans
        storage.upsertSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        storage.upsertSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20)
        )
        storage.upsertSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0)
        )

        // when cleaning up spans with a date
        storage.cleanUpSpans(date: Date(timeIntervalSince1970: 15))

        // then closed spans older than that date are removed
        // and open spans remain untouched
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 2)
        XCTAssertNil(spans.first(where: { $0.id == "id1" }))
        XCTAssertNotNil(spans.first(where: { $0.id == "id2" }))

        let span3 = spans.first(where: { $0.id == "id3" })
        XCTAssertNotNil(span3)
        XCTAssertNil(span3!.endTime)
    }

    func test_cleanUpSpans_noDate() throws {
        // given insterted spans
        storage.upsertSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10),
            processId: TestConstants.processId
        )
        storage.upsertSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20),
            processId: TestConstants.processId
        )
        storage.upsertSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0)
        )

        // when cleaning up spans without a date
        storage.cleanUpSpans(date: nil)

        // then all closed spans are removed
        // and open spans remain untouched
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id3")
        XCTAssertNil(spans[0].endTime)
    }

    func test_closeOpenSpans() throws {
        // given insterted spans
        storage.upsertSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance, data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        storage.upsertSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 1),
            processId: TestConstants.processId
        )
        storage.upsertSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 2)
        )

        // when closing the spans
        let now = Date()
        storage.closeOpenSpans(endTime: now)

        // then all spans are correctly closed
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 3)

        let span1 = spans.first(where: { $0.id == "id1" })
        XCTAssertNotNil(span1!.endTime)
        XCTAssertNotEqual(span1!.endTime!.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.1)

        let span2 = spans.first(where: { $0.id == "id2" })
        XCTAssertEqual(span2!.endTime!.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.1)

        let span3 = spans.first(where: { $0.id == "id3" })
        XCTAssertNil(span3!.endTime)
    }

    // MARK: - SpanEvent Relationship Tests

    func test_spanRecord_hasEventsRelationship() throws {
        // given a span with events
        storage.upsertSpan(
            id: "id",
            name: "test_span",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: Date(),
            attributes: ["key": "value"]
        )
        storage.addEventsToSpan(id: "id", traceId: TestConstants.traceId, events: [event1])

        // when fetching the span
        let span = storage.fetchSpan(id: "id", traceId: TestConstants.traceId)

        // then the events relationship is populated
        XCTAssertNotNil(span)
        XCTAssertEqual(span?.events.count, 1)
        XCTAssertEqual(span?.events.first?.name, "event1")
        XCTAssertEqual(span?.events.first?.attributes["key"], "value")
    }

    func test_spanRecord_cascadeDeleteEvents() throws {
        // given a span with events
        storage.upsertSpan(
            id: "id",
            name: "test_span",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(),
            endTime: Date()
        )

        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: Date(),
            attributes: ["key": "value"]
        )
        let event2 = ImmutableSpanEventRecord(
            name: "event2",
            timestamp: Date(),
            attributes: ["key": "value"]
        )
        storage.addEventsToSpan(id: "id", traceId: TestConstants.traceId, events: [event1, event2])

        // verify events exist
        let spanBefore = storage.fetchSpan(id: "id", traceId: TestConstants.traceId)
        XCTAssertEqual(spanBefore?.events.count, 2)

        // when deleting the span
        storage.cleanUpSpans(date: Date().addingTimeInterval(100))

        // then the events are also deleted (cascade delete)
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 0)

        // verify there are no orphaned events
        let eventRequest = SpanEventRecord.createFetchRequest()
        let events: [SpanEventRecord] = storage.coreData.fetch(withRequest: eventRequest)
        XCTAssertEqual(events.count, 0)
    }

    func test_spanRecord_toImmutable_includesEvents() throws {
        // given a span with events added directly to storage
        storage.upsertSpan(
            id: "id",
            name: "test_span",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        let now = Date()
        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: now.addingTimeInterval(100),
            attributes: ["key1": "value1"]
        )
        let event2 = ImmutableSpanEventRecord(
            name: "event2",
            timestamp: now.addingTimeInterval(50),
            attributes: ["key2": "value2"]
        )
        storage.addEventsToSpan(id: "id", traceId: TestConstants.traceId, events: [event1, event2])

        // when converting to immutable
        let span = storage.fetchSpan(id: "id", traceId: TestConstants.traceId)

        // then events are included and sorted by timestamp
        XCTAssertNotNil(span)
        XCTAssertEqual(span?.events.count, 2)
        XCTAssertEqual(span?.events[0].name, "event2")  // earlier timestamp
        XCTAssertEqual(span?.events[1].name, "event1")  // later timestamp
    }

    func test_spanEventRecord_getAndSetAttributes() throws {
        // given a span
        storage.upsertSpan(
            id: "id",
            name: "test_span",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when adding an event with complex attributes
        let attributes = [
            "string_key": "string_value",
            "number_key": "123",
            "special_chars": "test@#$%"
        ]
        let event = ImmutableSpanEventRecord(
            name: "test_event",
            timestamp: Date(),
            attributes: attributes
        )
        storage.addEventsToSpan(id: "id", traceId: TestConstants.traceId, events: [event])

        // then attributes are correctly encoded and decoded
        let span = storage.fetchSpan(id: "id", traceId: TestConstants.traceId)
        XCTAssertNotNil(span)
        XCTAssertEqual(span?.events.count, 1)

        let retrievedEvent = span?.events.first
        XCTAssertEqual(retrievedEvent?.attributes["string_key"], "string_value")
        XCTAssertEqual(retrievedEvent?.attributes["number_key"], "123")
        XCTAssertEqual(retrievedEvent?.attributes["special_chars"], "test@#$%")
    }
}
