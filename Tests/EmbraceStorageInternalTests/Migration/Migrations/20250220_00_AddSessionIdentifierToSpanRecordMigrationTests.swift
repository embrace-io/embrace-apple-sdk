//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceStorageInternal
import EmbraceOTelInternal
import EmbraceCommonInternal
import GRDB
import OpenTelemetryApi

final class _0250220_00_AddSessionIdentifierToSpanRecordMigration: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_identifier() {
        let migration = AddSessionIdentifierToSpanRecordMigration()
        XCTAssertEqual(migration.identifier, "AddSessionIdentifierToSpanRecord")
    }

    func test_perform_withNoExistingRecords() throws {
        let migration = AddSessionIdentifierToSpanRecordMigration()
        try storage.performMigration(migrations: .current.upTo(identifier: migration.identifier))

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(SpanRecord.databaseTableName))

            let columns = try db.columns(in: SpanRecord.databaseTableName)
            XCTAssertEqual(columns.count, 9)

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

            // session_identifier
            let sessionIdentifier = columns.first { info in
                info.name == SpanRecord.Schema.sessionIdentifier.name &&
                info.type == "TEXT"
            }
            XCTAssertNotNil(sessionIdentifier)
        }
    }

    func test_perform_migratesExistingEntries() throws {
        let migration = AddSessionIdentifierToSpanRecordMigration()
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
                    'data',
                    'process_identifier'
                ) VALUES (
                    ?,
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
                Data(),
                "c0ffee"
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
                XCTAssertNil(record.sessionIdentifier)
            }
        }
    }
}
