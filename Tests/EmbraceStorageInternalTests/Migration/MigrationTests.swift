//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorageInternal
import GRDB

final class MigrationTests: XCTestCase {

    func test_migration_hasDefault_foreignKeyChecks() throws {
        let migration = ExampleMigration()

        XCTAssertEqual(migration.foreignKeyChecks, .immediate)
        XCTAssertEqual(type(of: migration).foreignKeyChecks, .immediate)
    }

    func test_migration_allowsForCustom_foreignKeyChecks() throws {

        let migration = CustomForeignKeyMigration()

        XCTAssertEqual(migration.foreignKeyChecks, .deferred)
        XCTAssertEqual(type(of: migration).foreignKeyChecks, .deferred)

        XCTAssertEqual(migration.identifier, "CustomForeignKeyMigration_001")
        XCTAssertEqual(type(of: migration).identifier, "CustomForeignKeyMigration_001")
    }
}

extension MigrationTests {
    struct ExampleMigration: Migration {
        static let identifier = "ExampleMigration_001"
        func perform(_ db: GRDB.Database) throws { }
    }

    struct CustomForeignKeyMigration: Migration {
        static let foreignKeyChecks: DatabaseMigrator.ForeignKeyChecks = .deferred

        static let identifier = "CustomForeignKeyMigration_001"
        func perform(_ db: GRDB.Database) throws { }
    }
}
