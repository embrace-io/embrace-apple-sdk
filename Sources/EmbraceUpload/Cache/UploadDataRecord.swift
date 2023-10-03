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

extension UploadDataRecord: TableRecord {
    public static let databaseTableName: String = "uploads"

    internal static func defineTable(db: Database) throws {
        try db.create(table: UploadDataRecord.databaseTableName, options: .ifNotExists) { t in

            t.column("id", .text).notNull()
            t.column("type", .integer).notNull()
            t.primaryKey(["id", "type"])

            t.column("data", .blob).notNull()
            t.column("attempt_count", .integer).notNull()
            t.column("date", .datetime).notNull()
        }
    }
}

extension UploadDataRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}
