//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import GRDB
import EmbraceCommon

public protocol MigrationServiceProtocol {
    func perform(_ dbQueue: DatabaseWriter, migrations: [Migration]) throws
}

final public class MigrationService: MigrationServiceProtocol {

    let logger: InternalLogger

    public init(logger: InternalLogger) {
        self.logger = logger
    }

    public func perform(_ dbQueue: DatabaseWriter, migrations: [Migration]) throws {
        guard migrations.count > 0 else {
            logger.debug("No migrations to perform")
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
                logger.debug("DB is up to date")
                return
            } else {
                logger.debug("Running up to \(migrations.count) migrations")
            }
        }

        try migrator.migrate(dbQueue)
    }
}
