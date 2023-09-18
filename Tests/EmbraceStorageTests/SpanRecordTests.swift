//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceStorage

class SpanRecordTests: XCTestCase {

    let testOptions = EmbraceStorageOptions(baseUrl: URL(fileURLWithPath: NSTemporaryDirectory()), fileName: "test.sqlite")!

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: testOptions.filePath) {
            try FileManager.default.removeItem(atPath: testOptions.filePath)
        }
    }

    override func tearDownWithError() throws {

    }

    func test_tableSchema() throws {
        // given new storage
        let storage = try EmbraceStorage(options: testOptions)

        let expectation = XCTestExpectation()

        // then the table and its colums should be correct
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(SpanRecord.databaseTableName))

            let columns = try db.columns(in: SpanRecord.databaseTableName)

            // primary key
            XCTAssert(try db.table(SpanRecord.databaseTableName, hasUniqueKey: ["trace_id", "id"]))

            // id
            let idColumn = columns.first(where: { $0.name == "id" })
            if let idColumn = idColumn {
                XCTAssertEqual(idColumn.type, "TEXT")
                XCTAssert(idColumn.isNotNull)
            } else {
                XCTAssert(false, "id column not found!")
            }

            // trace_id
            let traceIdColumn = columns.first(where: { $0.name == "trace_id" })
            if let traceIdColumn = traceIdColumn {
                XCTAssertEqual(traceIdColumn.type, "TEXT")
                XCTAssert(traceIdColumn.isNotNull)
            } else {
                XCTAssert(false, "trace_id column not found!")
            }

            // type
            let typeColumn = columns.first(where: { $0.name == "type" })
            if let typeColumn = typeColumn {
                XCTAssertEqual(typeColumn.type, "TEXT")
                XCTAssert(typeColumn.isNotNull)
            } else {
                XCTAssert(false, "type column not found!")
            }

            // start_time
            let startTimeColumn = columns.first(where: { $0.name == "start_time" })
            if let startTimeColumn = startTimeColumn {
                XCTAssertEqual(startTimeColumn.type, "DATETIME")
                XCTAssert(startTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "start_time column not found!")
            }

            // end_time
            let endTimeColumn = columns.first(where: { $0.name == "end_time" })
            if let endTimeColumn = endTimeColumn {
                XCTAssertEqual(endTimeColumn.type, "DATETIME")
            } else {
                XCTAssert(false, "end_time column not found!")
            }

            // data
            let dataColumn = columns.first(where: { $0.name == "data" })
            if let dataColumn = dataColumn {
                XCTAssertEqual(dataColumn.type, "BLOB")
                XCTAssert(dataColumn.isNotNull)
            } else {
                XCTAssert(false, "data column not found!")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_addSpan() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted span
        let span = try storage.addSpan(id: "id", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)
        XCTAssertNotNil(span)

        // then span should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_upsertSpan() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted span
        let span = SpanRecord(id: "id", traceId: "tradeId", type: "type", data: Data(), startTime: Date())
        try storage.upsertSpan(span)

        // then span should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchSpan() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted span
        let original = try storage.addSpan(id: "id", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)

        // when fetching the span
        let span = try storage.fetchSpan(id: "id", traceId: "traceId")

        // then the span should be valid
        XCTAssertNotNil(span)
        XCTAssertEqual(original, span)
    }

    func test_fetchSpans() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)

        // when fetching the spans
        let spans = try storage.fetchSpans(traceId: "traceId")

        // then the fetched spans are valid
        XCTAssert(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssert(spans.contains(span3))
    }

    func test_fetchOpenSpans() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))

        // when fetching the open spans
        let spans = try storage.fetchOpenSpans(traceId: "traceId")

        // then the fetched spans are valid
        XCTAssert(spans.contains(span1))
        XCTAssertFalse(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }

    func test_fetchOpenSpans_type() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type1", data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type1", data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type2", data: Data(), startTime: Date(), endTime: nil)

        // when fetching the open spans
        let spans = try storage.fetchOpenSpans(traceId: "traceId", type: "type1")

        // then the fetched spans are valid
        XCTAssert(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }

    func test_spanCount_traceId() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        _ = try storage.addSpan(id: "id1", traceId: "traceId", type: "type1", data: Data(), startTime: Date(), endTime: nil)
        _ = try storage.addSpan(id: "id2", traceId: "traceId", type: "type1", data: Data(), startTime: Date(), endTime: nil)
        _ = try storage.addSpan(id: "id3", traceId: "traceId", type: "type2", data: Data(), startTime: Date(), endTime: nil)

        // then the span count should be correct
        let count = try storage.spanCount(traceId: "traceId", type: "type1")
        XCTAssertEqual(count, 2)
    }

    func test_fetchSpans_traceId_type() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type1", data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type1", data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type2", data: Data(), startTime: Date(), endTime: nil)

        // when fetching the spans
        let spans = try storage.fetchSpans(traceId: "traceId", type: "type1")

        // then the fetched spans are valid
        XCTAssert(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }

    func test_fetchSpans_traceId_type_limit() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type", data: Data(), startTime: Date(timeIntervalSinceNow: 10), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type", data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type", data: Data(), startTime: Date(timeIntervalSinceNow: 20), endTime: nil)

        // when fetching the spans
        let spans = try storage.fetchSpans(traceId: "traceId", type: "type", limit: 1)

        // then the fetched spans are valid
        XCTAssertEqual(spans.count, 1)
        XCTAssertFalse(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }

    func test_spanCount_date() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let now = Date()
        _ = try storage.addSpan(id: "id1", traceId: "traceId", type: "type1", data: Data(), startTime: now, endTime: nil)
        _ = try storage.addSpan(id: "id2", traceId: "traceId", type: "type1", data: Data(), startTime: now.addingTimeInterval(10), endTime: nil)
        _ = try storage.addSpan(id: "id3", traceId: "traceId", type: "type2", data: Data(), startTime: now.addingTimeInterval(15), endTime: nil)

        // then the span count should be correct
        let count = try storage.spanCount(startTime: now.addingTimeInterval(5), type: "type1")
        XCTAssertEqual(count, 1)
    }

    func test_fetchSpans_date_type() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type", data: Data(), startTime: now, endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type", data: Data(), startTime: now.addingTimeInterval(10), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type", data: Data(), startTime: now.addingTimeInterval(15), endTime: nil)

        // when fetching the spans
        let spans = try storage.fetchSpans(startTime: now.addingTimeInterval(5), type: "type")

        // then the fetched spans are valid
        XCTAssertFalse(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssert(spans.contains(span3))
    }

    func test_fetchSpans_date_type_limit() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: "type", data: Data(), startTime: now, endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: "type", data: Data(), startTime: now.addingTimeInterval(10), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: "type", data: Data(), startTime: now.addingTimeInterval(15), endTime: nil)

        // when fetching the spans
        let spans = try storage.fetchSpans(startTime: now.addingTimeInterval(5), type: "type", limit: 1)

        // then the fetched spans are valid
        XCTAssertEqual(spans.count, 1)
        XCTAssertFalse(spans.contains(span1))
        XCTAssert(spans.contains(span2))
        XCTAssertFalse(spans.contains(span3))
    }
}
