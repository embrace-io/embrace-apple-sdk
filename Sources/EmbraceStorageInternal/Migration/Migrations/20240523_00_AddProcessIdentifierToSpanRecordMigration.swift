//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import GRDB

struct AddProcessIdentifierToSpanRecordMigration: Migration {
    static var identifier = "AddProcessIdentifierToSpanRecord" // DEV: Must not change

    private static var tempSpansTableName = "spans_temp"

    func perform(_ db: GRDB.Database) throws {

        // create copy of `spans` table in `spans_temp`
        // include new column 'process_identifier'
        try db.create(table: Self.tempSpansTableName) { t in

            t.column(SpanRecord.Schema.id.name, .text).notNull()
            t.column(SpanRecord.Schema.traceId.name, .text).notNull()
            t.primaryKey([SpanRecord.Schema.traceId.name, SpanRecord.Schema.id.name])

            t.column(SpanRecord.Schema.name.name, .text).notNull()
            t.column(SpanRecord.Schema.type.name, .text).notNull()
            t.column(SpanRecord.Schema.startTime.name, .datetime).notNull()
            t.column(SpanRecord.Schema.endTime.name, .datetime)
            t.column(SpanRecord.Schema.data.name, .blob).notNull()

            // include new column into `spans_temp` table
            t.column(SpanRecord.Schema.processIdentifier.name, .text).notNull()
        }

        // copy all existing data into temp table
        // include default value for `process_identifier`
        try db.execute(literal: """
            INSERT INTO 'spans_temp' (
                'id',
                'trace_id',
                'name',
                'type',
                'start_time',
                'end_time',
                'data',
                'process_identifier'
            ) SELECT
                id,
                trace_id,
                name,
                type,
                start_time,
                end_time,
                data,
                'c0ffee'
            FROM 'spans'
        """)

        // drop original table
        try db.drop(table: SpanRecord.databaseTableName)

        // rename temp table to be original table
        try db.rename(table: Self.tempSpansTableName, to: SpanRecord.databaseTableName)

        // Create Trigger on new spans table to prevent endTime from being modified on SpanRecord
        try db.execute(sql:
        """
            CREATE TRIGGER IF NOT EXISTS prevent_closed_span_modification
            BEFORE UPDATE ON \(SpanRecord.databaseTableName)
            WHEN OLD.end_time IS NOT NULL
            BEGIN
                SELECT RAISE(ABORT,'Attempted to modify an already closed span.');
            END;
        """ )
    }
}
