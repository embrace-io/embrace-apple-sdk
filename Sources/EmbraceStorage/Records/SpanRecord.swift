//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

/// Represents a span in the storage
public struct SpanRecord: Codable {
    var id: String
    var traceId: String
    var type: String
    var data: Data
    var startTime: Date
    var endTime: Date?
}

extension SpanRecord: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
}

extension SpanRecord: TableRecord {
    public static let databaseTableName: String = "spans"

    internal static func defineTable(db: Database) throws {
        try db.create(table: SpanRecord.databaseTableName, options: .ifNotExists) { t in

            t.column("id", .text).notNull()
            t.column("trace_id", .text).notNull()
            t.primaryKey(["trace_id", "id"])

            t.column("type", .text).notNull()
            t.column("start_time", .datetime).notNull()
            t.column("end_time", .datetime)

            t.column("data", .blob).notNull()
        }
    }
}

extension SpanRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return
            lhs.id == rhs.id &&
            lhs.traceId == rhs.traceId &&
            lhs.type == rhs.type &&
            lhs.data == rhs.data
    }
}
