//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage
import GRDB

class SpanRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_tableSchema() throws {
        XCTAssertEqual(SpanRecord.databaseTableName, "spans")

        // then the table and its colums should be correct
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(SpanRecord.databaseTableName))

            let columns = try db.columns(in: SpanRecord.databaseTableName)
            XCTAssertEqual(columns.count, 7)

            // primary key
            XCTAssert(try db.table(
                SpanRecord.databaseTableName,
                hasUniqueKey: [
                    SpanRecord.Schema.traceId.name,
                    SpanRecord.Schema.id.name
                ]
            ))

            // id
            let idColumn = columns.first(where: { $0.name == SpanRecord.Schema.id.name })
            if let idColumn = idColumn {
                XCTAssertEqual(idColumn.type, "TEXT")
                XCTAssert(idColumn.isNotNull)
            } else {
                XCTAssert(false, "id column not found!")
            }

            // name
            let nameColumn = columns.first(where: { $0.name == SpanRecord.Schema.name.name })
            if let nameColumn = nameColumn {
                XCTAssertEqual(nameColumn.type, "TEXT")
                XCTAssert(nameColumn.isNotNull)
            } else {
                XCTAssert(false, "name column not found!")
            }

            // trace_id
            let traceIdColumn = columns.first(where: { $0.name == SpanRecord.Schema.traceId.name })
            if let traceIdColumn = traceIdColumn {
                XCTAssertEqual(traceIdColumn.type, "TEXT")
                XCTAssert(traceIdColumn.isNotNull)
            } else {
                XCTAssert(false, "trace_id column not found!")
            }

            // type
            let typeColumn = columns.first(where: { $0.name == SpanRecord.Schema.type.name })
            if let typeColumn = typeColumn {
                XCTAssertEqual(typeColumn.type, "TEXT")
                XCTAssert(typeColumn.isNotNull)
            } else {
                XCTAssert(false, "type column not found!")
            }

            // start_time
            let startTimeColumn = columns.first(where: { $0.name == SpanRecord.Schema.startTime.name })
            if let startTimeColumn = startTimeColumn {
                XCTAssertEqual(startTimeColumn.type, "DATETIME")
                XCTAssert(startTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "start_time column not found!")
            }

            // end_time
            let endTimeColumn = columns.first(where: { $0.name == SpanRecord.Schema.endTime.name })
            if let endTimeColumn = endTimeColumn {
                XCTAssertEqual(endTimeColumn.type, "DATETIME")
            } else {
                XCTAssert(false, "end_time column not found!")
            }

            // data
            let dataColumn = columns.first(where: { $0.name == SpanRecord.Schema.data.name })
            if let dataColumn = dataColumn {
                XCTAssertEqual(dataColumn.type, "BLOB")
                XCTAssert(dataColumn.isNotNull)
            } else {
                XCTAssert(false, "data column not found!")
            }
        }
    }

    func test_addSpan() throws {
        // given inserted span
        let span = try storage.addSpan(
            id: "id",
            name: "a name",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(),
            endTime: nil
        )
        XCTAssertNotNil(span)

        // then span should exist in storage
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
        }
    }

    func test_upsertSpan() throws {
        // given inserted span
        let span = SpanRecord(
            id: "id",
            name: "a name",
            traceId: "tradeId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )
        try storage.upsertSpan(span)

        // then span should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchSpan() throws {
        // given inserted span
        let original = try storage.addSpan(
            id: "id",
            name: "a name",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(),
            endTime: nil
        )

        // when fetching the span
        let span = try storage.fetchSpan(id: "id", traceId: TestConstants.traceId)

        // then the span should be valid
        XCTAssertNotNil(span)
        XCTAssertEqual(original, span)
    }

    func test_cleanUpSpans() throws {
        // given insterted spans
        _ = try storage.addSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        _ = try storage.addSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20)
        )
        _ = try storage.addSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0)
        )

        // when cleaning up spans with a date
        try storage.cleanUpSpans(date: Date(timeIntervalSince1970: 15))

        // then closed spans older than that date are removed
        // and open spans remain untouched
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            let spans = try SpanRecord
                .order(SpanRecord.Schema.startTime.asc)
                .fetchAll(db)

            XCTAssertEqual(spans.count, 2)
            XCTAssertEqual(spans[0].id, "id2")
            XCTAssertEqual(spans[1].id, "id3")
            XCTAssertNil(spans[1].endTime)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_cleanUpSpans_noDate() throws {
        // given insterted spans
        _ = try storage.addSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        _ = try storage.addSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 20)
        )
        _ = try storage.addSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 0)
        )

        // when cleaning up spans without a date
        try storage.cleanUpSpans(date: nil)

        // then all closed spans are removed
        // and open spans remain untouched
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            let spans = try SpanRecord.fetchAll(db)

            XCTAssertEqual(spans.count, 1)
            XCTAssertEqual(spans[0].id, "id3")
            XCTAssertNil(spans[0].endTime)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_closeOpenSpans() throws {
        // given insterted spans
        _ = try storage.addSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance, data: Data(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )
        _ = try storage.addSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 1)
        )
        _ = try storage.addSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: Date(timeIntervalSince1970: 2)
        )

        // when closing the spans
        let now = Date()
        try storage.closeOpenSpans(endTime: now)

        // then all spans are correctly closed
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            let spans = try SpanRecord
                .order(SpanRecord.Schema.startTime.asc)
                .fetchAll(db)

            XCTAssertEqual(spans.count, 3)
            XCTAssertNotNil(spans[0].endTime)
            XCTAssertNotEqual(spans[0].endTime!.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.1)
            XCTAssertEqual(spans[1].endTime!.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.1)
            XCTAssertEqual(spans[2].endTime!.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.1)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchSpans_date_type() throws {
        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now,
            endTime: nil
        )
        let span2 = try storage.addSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now.addingTimeInterval(10),
            endTime: nil
        )
        let span3 = try storage.addSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now.addingTimeInterval(15),
            endTime: nil
        )

        // when fetching the spans
        let spans = try storage.fetchSpans(
            startTime: now.addingTimeInterval(5),
            endTime: now.addingTimeInterval(30),
            includeOlder: false
        )

        // then the fetched spans are valid
        XCTAssertFalse(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssert(spans.contains(span3))
    }

    func test_fetchSpans_date_type_limit() throws {
        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now,
            endTime: nil
        )
        let span2 = try storage.addSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now.addingTimeInterval(10),
            endTime: nil
        )
        let span3 = try storage.addSpan(
            id: "id3",
            name: "a name 3",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now.addingTimeInterval(15),
            endTime: nil
        )

        // when fetching the spans
        let spans = try storage.fetchSpans(
            startTime: now.addingTimeInterval(5),
            endTime: now.addingTimeInterval(30),
            includeOlder: false,
            limit: 1
        )

        // then the fetched spans are valid
        XCTAssertEqual(spans.count, 1)
        XCTAssertFalse(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }

    func test_fetchSpans_ignoreSessions() throws {
        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(
            id: "id1",
            name: "a name 1",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now,
            endTime: nil
        )
        let span2 = try storage.addSpan(
            id: "id2",
            name: "a name 2",
            traceId: TestConstants.traceId,
            type: .performance,
            data: Data(),
            startTime: now.addingTimeInterval(10),
            endTime: nil
        )
        let span3 = try storage.addSpan(
            id: "id3",
            name: "emb.session",
            traceId: TestConstants.traceId,
            type: SpanType.session,
            data: Data(),
            startTime: now.addingTimeInterval(15),
            endTime: now.addingTimeInterval(25)
        )

        // when fetching the spans
        let spans = try storage.fetchSpans(
            startTime: now.addingTimeInterval(5),
            endTime: now.addingTimeInterval(30),
            includeOlder: false,
            ignoreSessionSpans: true
        )

        // then the fetched spans are valid
        XCTAssertEqual(spans.count, 1)
        XCTAssertFalse(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }
}
