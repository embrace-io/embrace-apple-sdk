//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest
import EmbraceSemantics
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
            traceId: "traceId",
            name: "a name",
            type: .performance,
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
            traceId: "traceId",
            name: "a name",
            type: .performance,
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
            traceId: "traceId",
            name: "a name",
            type: .performance,
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
            traceId: TestConstants.traceId,
            name: "a name",
            type: .performance,
            startTime: Date(),
            endTime: nil
        )

        // when fetching the span
        let span = storage.fetchSpan(id: "id", traceId: TestConstants.traceId)

        // then the span should be valid
        XCTAssertNotNil(span)
        XCTAssertEqual(span!.context.spanId, "id")
        XCTAssertEqual(span!.context.traceId, TestConstants.traceId)
        XCTAssertEqual(span!.name, "a name")
        XCTAssertEqual(span!.type, .performance)
        XCTAssertNil(span!.endTime)
    }

    func test_cleanUpSpans() throws {
        // given inserted spans
        storage.upsertSpan(
            id: "id1",
            traceId: TestConstants.traceId,
            name: "a name 1",
            type: .performance,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        storage.upsertSpan(
            id: "id2",
            traceId: TestConstants.traceId,
            name: "a name 2",
            type: .performance,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20)
        )
        storage.upsertSpan(
            id: "id3",
            traceId: TestConstants.traceId,
            name: "a name 3",
            type: .performance,
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
            traceId: TestConstants.traceId,
            name: "a name 1",
            type: .performance,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10),
            processId: TestConstants.processId
        )
        storage.upsertSpan(
            id: "id2",
            traceId: TestConstants.traceId,
            name: "a name 2",
            type: .performance,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20),
            processId: TestConstants.processId
        )
        storage.upsertSpan(
            id: "id3",
            traceId: TestConstants.traceId,
            name: "a name 3",
            type: .performance,
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
            traceId: TestConstants.traceId,
            name: "a name 1",
            type: .performance,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        storage.upsertSpan(
            id: "id2",
            traceId: TestConstants.traceId,
            name: "a name 2",
            type: .performance,
            startTime: Date(timeIntervalSince1970: 1),
            processId: TestConstants.processId
        )
        storage.upsertSpan(
            id: "id3",
            traceId: TestConstants.traceId,
            name: "a name 3",
            type: .performance,
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

    // MARK: Attributes
    func test_createAttributes() {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            attributes: ["key": "value"]
        )

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
        XCTAssertEqual(spans[0].attributes, "key,value")
    }

    func test_updateAttributes() {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date()
        )

        // when updating it
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            attributes: ["key": "value"]
        )

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
        XCTAssertEqual(spans[0].attributes, "key,value")
    }

    func test_setSpanAttributes() {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            attributes: ["key": "value"]
        )

        // when updating the attributes
        storage.setSpanAttributes(id: "id", traceId: "traceId", attributes: ["newKey": "newValue"])

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
        XCTAssertEqual(spans[0].attributes, "newKey,newValue")
    }

    func test_setSpanAttributes_remove() {
        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            attributes: ["key": "value"]
        )

        // when updating the attributes
        storage.setSpanAttributes(id: "id", traceId: "traceId", attributes: [:])

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")
        XCTAssertEqual(spans[0].attributes, "")
    }

    // MARK: Events
    func test_createSpanEvents() {
        let event = EmbraceSpanEvent(
            name: "test",
            timestamp: Date(),
            attributes: ["key": "value"]
        )

        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            events: [event]
        )

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")

        XCTAssertEqual(spans[0].events.count, 1)
        XCTAssertEqual(spans[0].events.first!.name, "test")
        XCTAssertTrue(spans[0].events.first!.attributes.contains("key,value"))
    }

    func test_updateSpanEvents() {
        let event1 = EmbraceSpanEvent(
            name: "test1",
            timestamp: Date(),
            attributes: ["key1": "value1"]
        )
        let event2 = EmbraceSpanEvent(
            name: "test2",
            timestamp: Date(),
            attributes: ["key2": "value2"]
        )

        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            events: [event1]
        )

        // when updating it
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            events: [event1, event2]
        )

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")

        XCTAssertEqual(spans[0].events.count, 2)

        let storedEvent1 = spans[0].events.first(where: { $0.name == "test1" })
        XCTAssertTrue(storedEvent1!.attributes.contains("key1,value1"))

        let storedEvent2 = spans[0].events.first(where: { $0.name == "test2" })
        XCTAssertTrue(storedEvent2!.attributes.contains("key2,value2"))
    }

    func test_addSpanEvent() {
        let event = EmbraceSpanEvent(
            name: "test",
            timestamp: Date(),
            attributes: ["key": "value"]
        )

        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date()
        )

        // when adding an event
        storage.addSpanEvent(id: "id", traceId: "traceId", event: event)

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")

        XCTAssertEqual(spans[0].events.count, 1)
        XCTAssertEqual(spans[0].events.first!.name, "test")
        XCTAssertTrue(spans[0].events.first!.attributes.contains("key,value"))
    }

    // MARK: Links
    func test_createSpanLinks() {
        let link = EmbraceSpanLink(
            spanId: "spanId",
            traceId: "traceId",
            attributes: ["key": "value"]
        )

        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            links: [link]
        )

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")

        XCTAssertEqual(spans[0].links.count, 1)
        XCTAssertEqual(spans[0].links.first!.spanId, "spanId")
        XCTAssertEqual(spans[0].links.first!.traceId, "traceId")
        XCTAssertEqual(spans[0].links.first!.attributes, "key,value")
    }

    func test_updateSpanLinks() {
        let link1 = EmbraceSpanLink(
            spanId: "spanId1",
            traceId: "traceId1",
            attributes: ["key1": "value1"]
        )
        let link2 = EmbraceSpanLink(
            spanId: "spanId2",
            traceId: "traceId2",
            attributes: ["key2": "value2"]
        )

        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            links: [link1]
        )

        // when updating it
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date(),
            links: [link1, link2]
        )

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")

        XCTAssertEqual(spans[0].links.count, 2)

        let storedLink1 = spans[0].links.first(where: { $0.spanId == "spanId1" })
        XCTAssertEqual(storedLink1!.traceId, "traceId1")
        XCTAssertEqual(storedLink1!.attributes, "key1,value1")

        let storedLink2 = spans[0].links.first(where: { $0.spanId == "spanId2" })
        XCTAssertEqual(storedLink2!.traceId, "traceId2")
        XCTAssertEqual(storedLink2!.attributes, "key2,value2")
    }

    func test_addSpanLink() {
        let link = EmbraceSpanLink(
            spanId: "spanId",
            traceId: "traceId",
            attributes: ["key": "value"]
        )

        // given inserted span
        storage.upsertSpan(
            id: "id",
            traceId: "traceId",
            name: "a name",
            type: .performance,
            startTime: Date()
        )

        // when adding an event
        storage.addSpanLink(id: "id", traceId: "traceId", link: link)

        // then span should exist in storage with the correct values
        let spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].id, "id")

        XCTAssertEqual(spans[0].links.count, 1)
        XCTAssertEqual(spans[0].links.first!.spanId, "spanId")
        XCTAssertEqual(spans[0].links.first!.traceId, "traceId")
        XCTAssertEqual(spans[0].links.first!.attributes, "key,value")
    }
}
