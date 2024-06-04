//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import GRDB
@testable import EmbraceStorage

class EmbraceStorageTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_databaseSchema() throws {
        // then all required tables should be present
        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(SessionRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(SpanRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(MetadataRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(LogRecord.databaseTableName))
        }
    }

    func test_performMigration_generatesTables() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)

        try storage.dbQueue.read { db in
            XCTAssertFalse(try db.tableExists(SessionRecord.databaseTableName))
            XCTAssertFalse(try db.tableExists(SpanRecord.databaseTableName))
            XCTAssertFalse(try db.tableExists(MetadataRecord.databaseTableName))
            XCTAssertFalse(try db.tableExists(LogRecord.databaseTableName))
        }

        try storage.performMigration()

        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(SessionRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(SpanRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(MetadataRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(LogRecord.databaseTableName))
        }
    }

    func test_performMigration_ifResetsIfErrorTrue_resetsDB() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        let migration = ThrowingMigration(performToThrow: 1)
        try storage.performMigration(resetIfError: true, migrations: .current + [migration])

        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(SessionRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(SpanRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(MetadataRecord.databaseTableName))
            XCTAssertTrue(try db.tableExists(LogRecord.databaseTableName))
        }

        XCTAssertEqual(migration.currentPerformCount, 2)
    }

    func test_performMigration_ifResetsIfErrorTrue_andMigrationFailsTwice_rethrowsError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        let migration = ThrowingMigration(performsToThrow: [1, 2])
        XCTAssertThrowsError(
            try storage.performMigration(
                resetIfError: true,
                migrations: [migration]
            )
        )

        XCTAssertEqual(migration.currentPerformCount, 2)
    }

    func test_performMigration_ifResetsIfErrorFalse_rethrowsError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        let migration = ThrowingMigration(performToThrow: 1)

        XCTAssertThrowsError(
            try storage.performMigration(
                resetIfError: false,
                migrations: [migration]
            )
        )
        XCTAssertEqual(migration.currentPerformCount, 1)
    }

    func test_reset_remakesDB() throws {
        storage = try .createInDiskDb() // need to use on disk DB, 
        // inMemory will keep same memory instance because dbQueue `name` is the same.

        // given inserted record
        let span = SpanRecord(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        try storage.dbQueue.write { db in
            try span.insert(db)
        }

        try storage.reset()

        // then record should not exist in storage
        try storage.dbQueue.read { db in
            XCTAssertFalse(try span.exists(db))
        }

        try FileManager.default.removeItem(at: storage.options.fileURL!)
    }

// MARK: - DB actions

    func test_update() throws {
        // given inserted record
        var span = SpanRecord(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        try storage.dbQueue.write { db in
            try span.insert(db)
        }

        // then record should exist in storage
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
        }

        // when updating record
        let endTime = Date(timeInterval: 10, since: span.startTime)
        span.endTime = endTime

        try storage.update(record: span)

        // the record should update successfuly
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(span.endTime, endTime)
        }
    }

    func test_delete() throws {
        // given inserted record
        let span = SpanRecord(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        try storage.dbQueue.write { db in
            try span.insert(db)
        }

        // then record should exist in storage
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
        }

        // when deleting record
        let success = try storage.delete(record: span)
        XCTAssert(success)

        // then record should not exist in storage
        try storage.dbQueue.read { db in
            XCTAssertFalse(try span.exists(db))
        }
    }

    func test_fetchAll() throws {
        // given inserted records
        let span1 = SpanRecord(
            id: "id1",
            name: "a name 1",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )
        let span2 = SpanRecord(
            id: "id2",
            name: "a name 2",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

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
        // given inserted record
        let span = SpanRecord(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

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

    func test_corruptedDbAction() {
        guard let corruptedDb = EmbraceStorageTests.prepareCorruptedDBForTest() else {
            return XCTFail("\(#function): Failed to create corrupted DB for test")
        }

        let dbBaseUrl = corruptedDb.deletingLastPathComponent()
        let dbFile = corruptedDb.lastPathComponent

        /// Make sure the target DB is corrupted and GRDB returns the expected result when trying to load it.
        let corruptedAttempt = Result(catching: { try DatabaseQueue(path: corruptedDb.absoluteString) })
        if case let .failure(error as DatabaseError) = corruptedAttempt {
            XCTAssertEqual(error.resultCode, .SQLITE_CORRUPT)
        } else {
            XCTFail("\(#function): Failed to load a corrupted db for test.")
        }

        /// Attempting to create an EmbraceStorage with the corrupted DB should result in a valid storage creation
        let storeCreationAttempt = Result(catching: {
            try EmbraceStorage(options: .init(baseUrl: dbBaseUrl, fileName: dbFile))
        })
        if case let .failure(error) = storeCreationAttempt {
            XCTFail("\(#function): EmbraceStorage failed to recover from corrupted existing DB: \(error)")
        }

        /// Then the corrupted DB should've been corrected and now GRDB should be able to load it.
        let fixedAttempt = Result(catching: { try DatabaseQueue(path: corruptedDb.absoluteString) })
        if case let .failure(error) = fixedAttempt {
            XCTFail("\(#function): DB Is still corrupted after it should've been fixed: \(error)")
        }
    }

    static func prepareCorruptedDBForTest() -> URL? {
        guard
            let resourceUrl = Bundle.module.path(forResource: "db_corrupted", ofType: "sqlite", inDirectory: "Mocks"),
            let corruptedDbPath = URL(string: "file://\(resourceUrl)")
        else {
            return nil
        }

        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let copyCorruptedPath = temporaryDirectoryURL.appendingPathComponent("db.sqlite")

        do {
            if !FileManager.default.fileExists(atPath: temporaryDirectoryURL.path, isDirectory: nil) {
                try FileManager.default.createDirectory(
                    at: temporaryDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            if FileManager.default.fileExists(atPath: copyCorruptedPath.path) {
                try FileManager.default.removeItem(at: copyCorruptedPath)
            }

            try FileManager.default.copyItem(at: corruptedDbPath, to: copyCorruptedPath)
            return copyCorruptedPath
        } catch let e {
            print("\(#function): error creating corrupt db: \(e)")
            return nil
        }

    }
}
