//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import GRDB
import EmbraceCommon

public protocol MigrationServiceProtocol {
    func perform(_ dbQueue: DatabaseWriter, migrations: [Migration]) throws
}

final public class MigrationService: MigrationServiceProtocol {
    public init() { }

    public func perform(_ dbQueue: DatabaseWriter, migrations: [Migration]) throws {
        guard migrations.count > 0 else {
            ConsoleLog.debug("No migrations to perform")
            return
        }

        var migrator = DatabaseMigrator()
        migrations.forEach { migration in
            migrator.registerMigration(migration.identifier,
                                       foreignKeyChecks: migration.foreignKeyChecks,
                                       migrate: migration.perform(_:))
        }

        try dbQueue.read { db in
            if try migrator.hasCompletedMigrations(db) {
                ConsoleLog.debug("DB is up to date")
                return
            } else {
                ConsoleLog.debug("Running up to \(migrations.count) migrations")
            }
        }

        try migrator.migrate(dbQueue)
    }
}
