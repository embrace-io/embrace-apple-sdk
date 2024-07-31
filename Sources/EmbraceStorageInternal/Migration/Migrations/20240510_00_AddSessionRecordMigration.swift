//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import GRDB

struct AddSessionRecordMigration: Migration {
    static var identifier = "CreateSessionRecordTable" // DEV: Must not change

    func perform(_ db: GRDB.Database) throws {
        try db.create(table: SessionRecord.databaseTableName, options: .ifNotExists) { t in

            t.primaryKey(SessionRecord.Schema.id.name, .text).notNull()

            t.column(SessionRecord.Schema.state.name, .text).notNull()
            t.column(SessionRecord.Schema.processId.name, .text).notNull()
            t.column(SessionRecord.Schema.traceId.name, .text).notNull()
            t.column(SessionRecord.Schema.spanId.name, .text).notNull()

            t.column(SessionRecord.Schema.startTime.name, .datetime).notNull()
            t.column(SessionRecord.Schema.endTime.name, .datetime)
            t.column(SessionRecord.Schema.lastHeartbeatTime.name, .datetime).notNull()

            t.column(SessionRecord.Schema.coldStart.name, .boolean)
                .notNull()
                .defaults(to: false)

            t.column(SessionRecord.Schema.cleanExit.name, .boolean)
                .notNull()
                .defaults(to: false)

            t.column(SessionRecord.Schema.appTerminated.name, .boolean)
                .notNull()
                .defaults(to: false)

            t.column(SessionRecord.Schema.crashReportId.name, .text)
        }
    }
}
