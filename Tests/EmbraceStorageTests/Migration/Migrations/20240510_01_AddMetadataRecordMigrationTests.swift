//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorage
import GRDB

final class _0240510_01_AddMetadataRecordMigrationTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_identifier() {
        let migration = AddMetadataRecordMigration()
        XCTAssertEqual(migration.identifier, "CreateMetadataRecordTable")
    }

    func test_perform_createsTableWithCorrectSchema() throws {
        let migration = AddMetadataRecordMigration()

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(MetadataRecord.databaseTableName))

            XCTAssertTrue(
                try db.table(MetadataRecord.databaseTableName,
                             hasUniqueKey: [
                                 MetadataRecord.Schema.key.name,
                                 MetadataRecord.Schema.type.name,
                                 MetadataRecord.Schema.lifespan.name,
                                 MetadataRecord.Schema.lifespanId.name
                             ] )
            )

            let columns = try db.columns(in: MetadataRecord.databaseTableName)
            XCTAssertEqual(columns.count, 6)

            // key
            let keyColumn = columns.first { info in
                info.name == MetadataRecord.Schema.key.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(keyColumn)

            // value
            let valueColumn = columns.first { info in
                info.name == MetadataRecord.Schema.value.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(valueColumn)

            // type
            let typeColumn = columns.first { info in
                info.name == MetadataRecord.Schema.type.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(typeColumn)

            // lifespan
            let lifespanColumn = columns.first { info in
                info.name == MetadataRecord.Schema.lifespan.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(lifespanColumn)

            // lifespan_id
            let lifespanIdColumn = columns.first { info in
                info.name == MetadataRecord.Schema.lifespanId.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(lifespanIdColumn)

            // collected_at
            let collectedAtColumn = columns.first { info in
                info.name == MetadataRecord.Schema.collectedAt.name &&
                info.type == "DATETIME" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(collectedAtColumn)
        }
    }
}
