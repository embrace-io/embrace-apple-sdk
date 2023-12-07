//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceStorage

class EmbraceStorageTests: XCTestCase {

    let testOptions = EmbraceStorage.Options(
        baseUrl: URL(fileURLWithPath: NSTemporaryDirectory()),
        fileName: "test.sqlite"
    )

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: testOptions.filePath!) {
            try FileManager.default.removeItem(atPath: testOptions.filePath!)
        }
    }

    override func tearDownWithError() throws {

    }

    func test_databaseSchema() throws {
        // given new storage
        let storage = try EmbraceStorage(options: testOptions)

        let expectation = XCTestExpectation()

        // then all required tables should be present
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(SessionRecord.databaseTableName))
            XCTAssert(try db.tableExists(SpanRecord.databaseTableName))

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_update() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted record
        var span = SpanRecord(id: "id", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        try storage.dbQueue.write { db in
            try span.insert(db)
        }

        // then record should exist in storage
        let expectation1 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // when updating record
        let endTime = Date(timeInterval: 10, since: span.startTime)
        span.endTime = endTime

        try storage.update(record: span)

        // the record should update successfuly
        let expectation2 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(span.endTime, endTime)

            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }

    func test_delete() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted record
        let span = SpanRecord(id: "id", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        try storage.dbQueue.write { db in
            try span.insert(db)
        }

        // then record should exist in storage
        let expectation1 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // when deleting record
        let success = try storage.delete(record: span)
        XCTAssert(success)

        // then record should not exist in storage
        let expectation2 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertFalse(try span.exists(db))
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }

    func test_fetchAll() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted records
        let span1 = SpanRecord(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        let span2 = SpanRecord(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        try storage.dbQueue.write { db in
            try span1.insert(db)
            try span2.insert(db)
        }

        // then records should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span1.exists(db))
            XCTAssert(try span2.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // when fetching all records
        let records: [SpanRecord] = try storage.fetchAll()

        // then all records should be successfuly fetched
        XCTAssert(records.count == 2)
        XCTAssert(records.contains(span1))
        XCTAssert(records.contains(span2))
    }

    func test_executeQuery() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted record
        let span = SpanRecord(id: "id", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        try storage.dbQueue.write { db in
            try span.insert(db)
        }

        // then record should exist in storage
        let expectation1 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // when executing custom query to delete record
        try storage.executeQuery("DELETE FROM \(SpanRecord.databaseTableName) WHERE id='id' AND trace_id='traceId'", arguments: nil)

        // then record should not exist in storage
        let expectation2 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertFalse(try span.exists(db))
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }
}
