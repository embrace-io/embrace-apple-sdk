//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import GRDB

struct AddMetadataRecordMigration: Migration {

    static var identifier = "CreateMetadataRecordTable" // DEV: Must not change

    func perform(_ db: Database) throws {
        try db.create(table: MetadataRecord.databaseTableName, options: .ifNotExists) { t in

            t.column(MetadataRecord.Schema.key.name, .text).notNull()
            t.column(MetadataRecord.Schema.value.name, .text).notNull()
            t.column(MetadataRecord.Schema.type.name, .text).notNull()
            t.column(MetadataRecord.Schema.lifespan.name, .text).notNull()
            t.column(MetadataRecord.Schema.lifespanId.name, .text).notNull()
            t.column(MetadataRecord.Schema.collectedAt.name, .datetime).notNull()

            t.primaryKey([
                MetadataRecord.Schema.key.name,
                MetadataRecord.Schema.type.name,
                MetadataRecord.Schema.lifespan.name,
                MetadataRecord.Schema.lifespanId.name
            ])
        }
    }
}
