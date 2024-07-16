//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import GRDB

struct AddLogRecordMigration: Migration {

    static var identifier = "CreateLogRecordTable" // DEV: Must not change

    func perform(_ db: Database) throws {
        try db.create(table: LogRecord.databaseTableName, options: .ifNotExists) { t in
            t.primaryKey(LogRecord.Schema.identifier.name, .text).notNull()
            t.column(LogRecord.Schema.processIdentifier.name, .integer).notNull()
            t.column(LogRecord.Schema.severity.name, .integer).notNull()
            t.column(LogRecord.Schema.body.name, .text).notNull()
            t.column(LogRecord.Schema.timestamp.name, .datetime).notNull()
            t.column(LogRecord.Schema.attributes.name, .text).notNull()
        }
    }
}
