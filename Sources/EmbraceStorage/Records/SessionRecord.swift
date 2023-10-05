//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

/// Represents a session in the storage
public struct SessionRecord: Codable {
    public var id: SessionId
    public var rawState: Int
    public var startTime: Date
    public var endTime: Date?

    public var state: EmbraceSemantics.SessionState {
        return EmbraceSemantics.SessionState(rawValue: rawState) ?? .foreground
    }

    internal init(id: SessionId, state: EmbraceSemantics.SessionState, startTime: Date, endTime: Date? = nil) {
        self.id = id
        self.rawState = state.rawValue
        self.startTime = startTime
        self.endTime = endTime
    }
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

            t.column("raw_state", .integer).notNull()

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
