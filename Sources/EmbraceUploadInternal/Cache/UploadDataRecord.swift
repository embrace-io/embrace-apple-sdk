//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

/// Represents a cached upload data in the storage
public struct UploadDataRecord: Codable {
    var id: String
    var type: Int
    var data: Data
    var attemptCount: Int
    var date: Date
}

extension UploadDataRecord: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
}

extension UploadDataRecord {
    struct Schema {
        static var id: Column { Column("id") }
        static var type: Column { Column("type") }
        static var data: Column { Column("data") }
        static var attemptCount: Column { Column("attempt_count") }
        static var date: Column { Column("date") }
    }
}

extension UploadDataRecord: TableRecord {
    public static let databaseTableName: String = "uploads"

    internal static func defineTable(db: Database) throws {
        try db.create(table: UploadDataRecord.databaseTableName, options: .ifNotExists) { t in
            t.column(Schema.id.name, .text).notNull()
            t.column(Schema.type.name, .integer).notNull()
            t.primaryKey([Schema.id.name, Schema.type.name])

            t.column(Schema.data.name, .blob).notNull()
            t.column(Schema.attemptCount.name, .integer).notNull()
            t.column(Schema.date.name, .datetime).notNull()
        }
    }
}

extension UploadDataRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}
