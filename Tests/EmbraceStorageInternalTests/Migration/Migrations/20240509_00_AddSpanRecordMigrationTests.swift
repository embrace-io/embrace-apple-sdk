//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorageInternal
import GRDB

final class AddSpanRecordMigrationTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_identifier() {
        let migration = AddSpanRecordMigration()
        XCTAssertEqual(migration.identifier, "CreateSpanRecordTable")
    }

    func test_perform_createsTableWithCorrectSchema() throws {
        let migration = AddSpanRecordMigration()

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(SpanRecord.databaseTableName))

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
        }
    }

    func test_perform_createsClosedSpanTrigger() throws {
        let migration = AddSpanRecordMigration()

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM sqlite_master where type = 'trigger'")
            XCTAssertEqual(rows.count, 1)

            let triggerRow = try XCTUnwrap(rows.first)
            XCTAssertEqual(triggerRow["name"], "prevent_closed_span_modification")
            XCTAssertEqual(triggerRow["tbl_name"], "spans")
        }
    }
}
