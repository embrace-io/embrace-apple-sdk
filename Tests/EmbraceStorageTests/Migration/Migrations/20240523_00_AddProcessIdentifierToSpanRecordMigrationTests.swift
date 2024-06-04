//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorage
import EmbraceOTel
import EmbraceCommon
import GRDB

final class _0240523_00_AddProcessIdentifierToSpanRecordMigration: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_identifier() {
        let migration = AddProcessIdentifierToSpanRecordMigration()
        XCTAssertEqual(migration.identifier, "AddProcessIdentifierToSpanRecord")
    }

    func test_perform_withNoExistingRecords() throws {
        let migration = AddProcessIdentifierToSpanRecordMigration()
        try storage.performMigration(migrations: .current.upTo(identifier: migration.identifier))

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(SpanRecord.databaseTableName))

            let columns = try db.columns(in: SpanRecord.databaseTableName)
            XCTAssertEqual(columns.count, 8)

            // primary key
            XCTAssert(try db.table(
                SpanRecord.databaseTableName,
                hasUniqueKey: [
                    SpanRecord.Schema.traceId.name,
                    SpanRecord.Schema.id.name
                ]
            ))

            // id
            let idColumn = columns.first { info in
                info.name == SpanRecord.Schema.id.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(idColumn)

            // name
            let nameColumn = columns.first { info in
                info.name == SpanRecord.Schema.name.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(nameColumn)

            // trace_id
            let traceIdColumn = columns.first { info in
                info.name == SpanRecord.Schema.traceId.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(traceIdColumn)

            // type
            let typeColumn = columns.first { info in
                info.name == SpanRecord.Schema.type.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(typeColumn)

            // start_time
            let startTimeColumn = columns.first { info in
                info.name == SpanRecord.Schema.startTime.name &&
                info.type == "DATETIME" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(startTimeColumn)

            // end_time
            let endTimeColumn = columns.first { info in
                info.name == SpanRecord.Schema.endTime.name &&
                info.type == "DATETIME" &&
                info.isNotNull == false
            }
            XCTAssertNotNil(endTimeColumn)

            // data
            let dataColumn = columns.first { info in
                info.name == SpanRecord.Schema.data.name &&
                info.type == "BLOB" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(dataColumn)

            // process_identifier
            let processIdentifier = columns.first { info in
                info.name == SpanRecord.Schema.processIdentifier.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(processIdentifier)
        }
    }

    func test_perform_migratesExistingEntries() throws {
        let migration = AddProcessIdentifierToSpanRecordMigration()
        try storage.performMigration(migrations: .current.upTo(identifier: migration.identifier))

        try storage.dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO 'spans' (
                    'id',
                    'trace_id',
                    'name',
                    'type',
                    'start_time',
                    'end_time',
                    'data'
                ) VALUES (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?
                );
            """, arguments: [
                "3d9381a7f8300102",
                "b65cd80e1bea6fd2c27150f8cce3de3e",
                "example-name",
                SpanType.performance,
                Date(),
                Date(timeIntervalSinceNow: 2),
                Data()
            ])
        }

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * from spans")
            XCTAssertEqual(rows.count, 1)

            let records = try SpanRecord.fetchAll(db)
            XCTAssertEqual(records.count, 1)
            records.forEach { record in
                XCTAssertEqual(record.processIdentifier, ProcessIdentifier(hex: "c0ffee"))
            }
        }
    }

    func test_perform_migratesExistingEntries_whenMultiple() throws {
        let migration = AddProcessIdentifierToSpanRecordMigration()
        try storage.performMigration(migrations: .current.upTo(identifier: migration.identifier))

        let count = 10
        for _ in 0..<count {
            try storage.dbQueue.write { db in
                try db.execute(sql: """
                INSERT INTO 'spans' (
                    'id',
                    'trace_id',
                    'name',
                    'type',
                    'start_time',
                    'end_time',
                    'data'
                ) VALUES (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?
                );
            """, arguments: [
                SpanId.random().hexString,
                TraceId.random().hexString,
                "example-name",
                SpanType.performance,
                Date(),
                Date(timeIntervalSinceNow: 2),
                Data()
            ])
            }
        }

        do {
            try storage.dbQueue.write { db in
                try migration.perform(db)
            }
        } catch {}

        try storage.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * from spans")
            XCTAssertEqual(rows.count, count)

            let records = try SpanRecord.fetchAll(db)
            XCTAssertEqual(records.count, count)
            records.forEach { record in
                XCTAssertEqual(record.processIdentifier, ProcessIdentifier(hex: "c0ffee"))
            }
        }
    }
}
