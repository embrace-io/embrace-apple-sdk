//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorage
import GRDB

final class _0240510_02_AddLogRecordMigrationTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_identifier() {
        let migration = AddLogRecordMigration()
        XCTAssertEqual(migration.identifier, "CreateLogRecordTable")
    }

    func test_perform_createsTableWithCorrectSchema() throws {
        let migration = AddLogRecordMigration()

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(LogRecord.databaseTableName))

            let columns = try db.columns(in: LogRecord.databaseTableName)

            XCTAssert(try db.table(
                LogRecord.databaseTableName,
                hasUniqueKey: ["identifier"]
            ))

            // identifier
            let idColumn = columns.first { info in
                info.name == "identifier" &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(idColumn, "identifier column not found!")

            // process_identifier
            let processIdColumn = columns.first { info in
                info.name == "process_identifier" &&
                info.type == "INTEGER" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(processIdColumn, "process_identifier column not found!")

            // severity
            let severityColumn = columns.first { info in
                info.name == "severity" &&
                info.type == "INTEGER" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(severityColumn, "severity column not found!")

            // body
            let bodyColumn = columns.first { info in
                info.name == "body" &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(bodyColumn, "body column not found!")

            // timestamp
            let timestampColumn = columns.first { info in
                info.name == "timestamp" &&
                info.type == "DATETIME" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(timestampColumn, "timestamp column not found!")

            // attributes
            let attributesColumn = columns.first { info in
                info.name == "attributes" &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(attributesColumn, "attributes column not found!")
        }
    }

}
