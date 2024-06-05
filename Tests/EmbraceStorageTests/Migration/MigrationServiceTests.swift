//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import GRDB
@testable import EmbraceStorage

class MigrationServiceTests: XCTestCase {
    var dbQueue: DatabaseQueue!
    var migrationService = MigrationService(logger: MockLogger())

    override func setUpWithError() throws {
        dbQueue = try DatabaseQueue(named: name)
    }

    func test_perform_runsMigrations_thatAreNotRun() throws {
        // Given an existing table
        try dbQueue.write { db in
            try TestMigrationRecord.defineTable(db: db)
        }

        // Checking it only contains the original schema
        try dbQueue.read { db in
            let columns = try db.columns(in: "test_migrations")
            XCTAssertEqual(columns.count, 1)
            XCTAssertEqual(columns[0].name, "id")
        }

        // When performing a migration
        let migrations: [Migration] = [
            AddColumnSomethingNew(),
            AddColumnSomethingNewer()
        ]
        try migrationService.perform(dbQueue, migrations: migrations)

        // Then all migrations have been completed and all new keys have been added to the table.
        try dbQueue.read { db in
            /// Check database now has 3 columns.
            let columns = try db.columns(in: "test_migrations")
            XCTAssertEqual(columns.count, 3)

            /// Check all expected migrations have been completed
            let identifiers = try DatabaseMigrator().appliedIdentifiers(db)
            XCTAssertEqual(
                Set(identifiers),
                Set(["AddColumnSomethingNew_1", "AddColumnSomethingNewer_2"])
            )

            /// Check new expected columns have been added.
            let somethingNew = columns.first { column in
                column.name == "something_new"
            }
            let somethingNewer = columns.first { column in
                column.name == "something_newer"
            }
            XCTAssertNotNil(somethingNew)
            XCTAssertNotNil(somethingNewer)
        }
    }

    func test_perform_whenTableIsDefined_andMigrationTriesToRedefineIt_doesNotFail() throws {
        // Given an existing table
        try dbQueue.write { db in
            try TestMigrationRecord.defineTable(db: db)
        }

        // When performing a migration
        try migrationService.perform(dbQueue, migrations: [
            InitialSchema(),
            AddColumnSomethingNew(),
            AddColumnSomethingNewer()
        ])

        try dbQueue.read { db in
            let columns = try db.columns(in: "test_migrations")
            XCTAssertEqual(columns.count, 3)

            XCTAssertNotNil(columns.first { info in
                info.name == "id" &&
                info.type == "TEXT" &&
                info.isNotNull
            })

            XCTAssertNotNil(columns.first { info in
                info.name == "something_new" &&
                info.type == "TEXT" &&
                info.isNotNull == false
            })

            XCTAssertNotNil(columns.first { info in
                info.name == "something_newer" &&
                info.type == "TEXT" &&
                info.isNotNull == false
            })
        }
    }

    func test_perform_whenRunMultipleTimes_doesNotFail() throws {
        for _ in 0..<5 {
            try migrationService.perform(dbQueue, migrations: [
                InitialSchema(),
                AddColumnSomethingNew(),
                AddColumnSomethingNewer()
            ])
        }

        try dbQueue.read { db in
            let columns = try db.columns(in: "test_migrations")

            XCTAssertEqual(columns.count, 3)
            XCTAssertNotNil(columns.first { info in
                info.name == "id" &&
                info.type == "TEXT" &&
                info.isNotNull
            })

            XCTAssertNotNil(columns.first { info in
                info.name == "something_new" &&
                info.type == "TEXT" &&
                info.isNotNull == false
            })

            XCTAssertNotNil(columns.first { info in
                info.name == "something_newer" &&
                info.type == "TEXT" &&
                info.isNotNull == false
            })
        }
    }
}

extension MigrationServiceTests {

    struct TestMigrationRecord: TableRecord {
        internal static func defineTable(db: Database) throws {
            try db.create(table: "test_migrations", options: .ifNotExists) { t in
                t.primaryKey("id", .text).notNull()
            }
        }
    }

    class InitialSchema: Migration {
        static var identifier = "Initial Schema"

        func perform(_ db: GRDB.Database) throws {
            try TestMigrationRecord.defineTable(db: db)
        }
    }

    class AddColumnSomethingNew: Migration {
        static let identifier = "AddColumnSomethingNew_1"

        func perform(_ db: Database) throws {
            try db.alter(table: "test_migrations") { table in
                table.add(column: "something_new", .text)
            }
        }
    }

    class AddColumnSomethingNewer: Migration {
        static let identifier: StringLiteralType = "AddColumnSomethingNewer_2"

        func perform(_ db: GRDB.Database) throws {
            try db.alter(table: "test_migrations") { table in
                table.add(column: "something_newer", .text)
            }
        }
    }

}
