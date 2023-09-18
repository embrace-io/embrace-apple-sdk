//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

public typealias SessionId = String

/// Represents a session in the storage
public struct SessionRecord: Codable {
    var id: SessionId
    var startTime: Date
    var endTime: Date?
}

extension SessionRecord: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
}

extension SessionRecord: TableRecord {
    public static let databaseTableName: String = "sessions"

    internal static func defineTable(db: Database) throws {
        try db.create(table: SessionRecord.databaseTableName, options: .ifNotExists) { t in

            t.primaryKey("id", .text).notNull()

            t.column("start_time", .datetime).notNull()
            t.column("end_time", .datetime)
        }
    }
}

extension SessionRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}
