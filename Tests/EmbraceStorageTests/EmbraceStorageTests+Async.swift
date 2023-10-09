//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceStorage

extension EmbraceStorageTests {

    func test_updateAsync() throws {
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

        wait(for: [expectation1], timeout: TestConstants.defaultTimeout)

        // when updating record
        let endTime = Date(timeInterval: 10, since: span.startTime)
        span.endTime = endTime

        let expectation2 = XCTestExpectation()
        storage.updateAsync(record: span, completion: { result in
            switch result {
            case .success:
                expectation2.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        })

        wait(for: [expectation2], timeout: TestConstants.defaultTimeout)

        // the record should update successfuly
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(span.endTime, endTime)
        }
    }

    func test_deleteAsync() throws {
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

        wait(for: [expectation1], timeout: TestConstants.defaultTimeout)

        // when deleting record
        let expectation2 = XCTestExpectation()
        storage.deleteAsync(record: span) { result in
            switch result {
            case .success:
                expectation2.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation2], timeout: TestConstants.defaultTimeout)

        // the record should update successfuly
        try storage.dbQueue.read { db in
            XCTAssertFalse(try span.exists(db))
        }
    }

    func test_fetchAllAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted records
        let span1 = SpanRecord(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        let span2 = SpanRecord(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date())
        try storage.dbQueue.write { db in
            try span1.insert(db)
            try span2.insert(db)
        }

        // then records should exist in storage
        let expectation1 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span1.exists(db))
            XCTAssert(try span2.exists(db))
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: TestConstants.defaultTimeout)

        // when fetching all records
        storage.fetchAllAsync { (result: Result<[SpanRecord], Error>) in
            switch result {
            case .success(let records):
                // then all records should be successfuly fetched
                XCTAssert(records.count == 2)
                XCTAssert(records.contains(span1))
                XCTAssert(records.contains(span2))

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }
    }

    func test_executeQueryAsync() throws {
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

        wait(for: [expectation1], timeout: TestConstants.defaultTimeout)

        // when executing custom query to delete record
        let expectation2 = XCTestExpectation()
        storage.executeQueryAsync("DELETE FROM \(SpanRecord.databaseTableName) WHERE id='id' AND trace_id='traceId'", arguments: nil) { result in

            switch result {
            case .success:
                expectation2.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation2], timeout: TestConstants.defaultTimeout)

        // then record should not exist in storage
        let expectation3 = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertFalse(try span.exists(db))
            expectation3.fulfill()
        }

        wait(for: [expectation3], timeout: TestConstants.defaultTimeout)
    }
}
