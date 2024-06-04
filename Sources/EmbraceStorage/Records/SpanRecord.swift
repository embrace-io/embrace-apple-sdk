//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

/// Represents a span in the storage
public struct SpanRecord: Codable {
    public var id: String
    public var name: String
    public var traceId: String
    public var type: SpanType
    public var data: Data
    public var startTime: Date
    public var endTime: Date?
    public var processIdentifier: ProcessIdentifier

    public init(
        id: String,
        name: String,
        traceId: String,
        type: SpanType,
        data: Data,
        startTime: Date,
        endTime: Date? = nil,
        processIdentifier: ProcessIdentifier = .current
    ) {
        self.id = id
        self.traceId = traceId
        self.type = type
        self.data = data
        self.startTime = startTime
        self.endTime = endTime
        self.name = name
        self.processIdentifier = processIdentifier
    }
}

extension SpanRecord {
    struct Schema {
        static var id: Column { Column("id") }
        static var traceId: Column { Column("trace_id") }
        static var type: Column { Column("type") }
        static var data: Column { Column("data") }
        static var startTime: Column { Column("start_time") }
        static var endTime: Column { Column("end_time") }
        static var name: Column { Column("name") }
        static var processIdentifier: Column { Column("process_identifier") }
    }
}

extension SpanRecord: FetchableRecord, PersistableRecord, MutablePersistableRecord {
    public static let databaseTableName: String = "spans"

    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
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
