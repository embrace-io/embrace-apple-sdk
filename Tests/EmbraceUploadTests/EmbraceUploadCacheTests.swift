//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceOTel
@testable import EmbraceUpload

class EmbraceUploadCacheTests: XCTestCase {
    let testOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
    var spanProcessor: MockSpanProcessor!

    override func setUpWithError() throws {
        spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
        if FileManager.default.fileExists(atPath: testOptions.cacheFilePath) {
            try FileManager.default.removeItem(atPath: testOptions.cacheFilePath)
        }
    }

    override func tearDownWithError() throws {

    }

    func test_tableSchema() throws {
        // given new cache
        let cache = try EmbraceUploadCache(options: testOptions)

        let expectation = XCTestExpectation()

        // then the table and its colums should be correct
        try cache.dbQueue.read { db in
            XCTAssert(try db.tableExists(UploadDataRecord.databaseTableName))

            let columns = try db.columns(in: UploadDataRecord.databaseTableName)

            XCTAssert(try db.table(UploadDataRecord.databaseTableName, hasUniqueKey: ["id", "type"]))

            // id
            let idColumn = columns.first(where: { $0.name == "id" })
            if let idColumn = idColumn {
                XCTAssertEqual(idColumn.type, "TEXT")
                XCTAssert(idColumn.isNotNull)
            } else {
                XCTAssert(false, "id column not found!")
            }

            // type
            let typeColumn = columns.first(where: { $0.name == "type" })
            if let typeColumn = typeColumn {
                XCTAssertEqual(typeColumn.type, "INTEGER")
                XCTAssert(typeColumn.isNotNull)
            } else {
                XCTAssert(false, "type column not found!")
            }

            // data
            let dataColumn = columns.first(where: { $0.name == "data" })
            if let dataColumn = dataColumn {
                XCTAssertEqual(dataColumn.type, "BLOB")
                XCTAssert(dataColumn.isNotNull)
            } else {
                XCTAssert(false, "data column not found!")
            }

            // attemptCount
            let attemptCountColumn = columns.first(where: { $0.name == "attempt_count" })
            if let attemptCountColumn = attemptCountColumn {
                XCTAssertEqual(attemptCountColumn.type, "INTEGER")
                XCTAssert(attemptCountColumn.isNotNull)
            } else {
                XCTAssert(false, "attempt_count column not found!")
            }

            // date
            let dateColumn = columns.first(where: { $0.name == "date" })
            if let dateColumn = dateColumn {
                XCTAssertEqual(dateColumn.type, "DATETIME")
                XCTAssert(dateColumn.isNotNull)
            } else {
                XCTAssert(false, "date column not found!")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchUploadData() throws {
        let cache = try EmbraceUploadCache(options: testOptions)

        // given inserted upload data
        let original = UploadDataRecord(
            id: "id",
            type: EmbraceUploadType.session.rawValue,
            data: Data(),
            attemptCount: 0,
            date: Date()
        )
        try cache.dbQueue.write { db in
            try original.insert(db)
        }

        // when fetching the upload data
        let uploadData = try cache.fetchUploadData(id: "id", type: .session)

        // then the upload data should be valid
        XCTAssertNotNil(uploadData)
        XCTAssertEqual(original, uploadData)
    }

    func test_fetchAllUploadData() throws {
        let cache = try EmbraceUploadCache(options: testOptions)

        // given inserted upload datas
        let data1 = UploadDataRecord(id: "id1", type: 0, data: Data(), attemptCount: 0, date: Date())
        let data2 = UploadDataRecord(id: "id2", type: 0, data: Data(), attemptCount: 0, date: Date())
        let data3 = UploadDataRecord(id: "id3", type: 0, data: Data(), attemptCount: 0, date: Date())

        try cache.dbQueue.write { db in
            try data1.insert(db)
            try data2.insert(db)
            try data3.insert(db)
        }

        // when fetching the upload datas
        let datas = try cache.fetchAllUploadData()

        // then the fetched datas are valid
        XCTAssert(datas.contains(data1))
        XCTAssert(datas.contains(data2))
        XCTAssert(datas.contains(data3))
    }

    func test_saveUploadData() throws {
        let cache = try EmbraceUploadCache(options: testOptions)

        // given inserted upload data
        let data = try cache.saveUploadData(id: "id", type: .session, data: Data())

        // then the upload data should exist
        let expectation = XCTestExpectation()
        try cache.dbQueue.read { db in
            XCTAssert(try data.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_saveUploadData_limit() throws {
        // given a cache with a limit of 1
        let options = EmbraceUpload.CacheOptions(
            cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()),
            cacheLimit: 1
        )!
        let cache = try EmbraceUploadCache(options: options)

        // given inserted upload datas
        let data1 = try cache.saveUploadData(id: "id1", type: .session, data: Data())
        let data2 = try cache.saveUploadData(id: "id2", type: .session, data: Data())
        let data3 = try cache.saveUploadData(id: "id3", type: .session, data: Data())

        // then only the last data should exist
        let expectation = XCTestExpectation()
        try cache.dbQueue.read { db in
            XCTAssertFalse(try data1.exists(db))
            XCTAssertFalse(try data2.exists(db))
            XCTAssert(try data3.exists(db))

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_deleteUploadData() throws {
        let cache = try EmbraceUploadCache(options: testOptions)

        // given inserted upload data
        let data = UploadDataRecord(
            id: "id",
            type: EmbraceUploadType.session.rawValue,
            data: Data(),
            attemptCount: 0,
            date: Date()
        )
        try cache.dbQueue.write { db in
            try data.insert(db)
        }

        // when deleting the data
        let success = try cache.deleteUploadData(id: "id", type: .session)
        XCTAssert(success)

        // then the upload data should not exist
        let expectation = XCTestExpectation()
        try cache.dbQueue.read { db in
            XCTAssertFalse(try data.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_updateAttemptCount() throws {
        let cache = try EmbraceUploadCache(options: testOptions)

        // given inserted upload data
        let original = UploadDataRecord(
            id: "id",
            type: EmbraceUploadType.session.rawValue,
            data: Data(),
            attemptCount: 0,
            date: Date()
        )
        try cache.dbQueue.write { db in
            try original.insert(db)
        }

        // when updating the attempt count
        _ = try cache.updateAttemptCount(id: "id", type: .session, attemptCount: 10)

        // then the data is updated successfully
        let expectation = XCTestExpectation()

        try cache.dbQueue.read { db in
            if let data = try UploadDataRecord.fetchOne(db) {
                XCTAssertEqual(data.attemptCount, 10)
                expectation.fulfill()
            } else {
                XCTAssert(false, "Invalid data!")
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
