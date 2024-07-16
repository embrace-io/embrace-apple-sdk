//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import GRDB

struct AddSpanRecordMigration: Migration {
    static let identifier = "CreateSpanRecordTable" // DEV: Must not change

    func perform(_ db: GRDB.Database) throws {
        try db.create(table: SpanRecord.databaseTableName, options: .ifNotExists) { t in
            t.column(SpanRecord.Schema.id.name, .text).notNull()
            t.column(SpanRecord.Schema.name.name, .text).notNull()
            t.column(SpanRecord.Schema.traceId.name, .text).notNull()
            t.primaryKey([SpanRecord.Schema.traceId.name, SpanRecord.Schema.id.name])

            t.column(SpanRecord.Schema.type.name, .text).notNull()
            t.column(SpanRecord.Schema.startTime.name, .datetime).notNull()
            t.column(SpanRecord.Schema.endTime.name, .datetime)

            t.column(SpanRecord.Schema.data.name, .blob).notNull()
        }

        let preventClosedSpanModification = """
        CREATE TRIGGER IF NOT EXISTS prevent_closed_span_modification
        BEFORE UPDATE ON \(SpanRecord.databaseTableName)
        WHEN OLD.end_time IS NOT NULL
        BEGIN
            SELECT RAISE(ABORT,'Attempted to modify an already closed span.');
        END;
        """

        try db.execute(sql: preventClosedSpanModification)
    }

}
