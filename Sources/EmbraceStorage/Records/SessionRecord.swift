//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

/// Represents a session in the storage
public struct SessionRecord: Codable {
    public var id: SessionIdentifier
    public var processId: ProcessIdentifier
    public var state: String
    public var traceId: String
    public var spanId: String
    public var startTime: Date
    public var endTime: Date?
    public var lastHeartbeatTime: Date
    public var crashReportId: String?

    /// Used to mark if the session is the first to occur during this process
    public var coldStart: Bool

    /// Used to mark the session ended in an expected manner
    public var cleanExit: Bool

    /// Used to mark the session that is active when the application was explicitly terminated by the user and/or system
    public var appTerminated: Bool

    public init(
        id: SessionIdentifier,
        state: SessionState,
        processId: ProcessIdentifier,
        traceId: String,
        spanId: String,
        startTime: Date,
        endTime: Date? = nil,
        lastHeartbeatTime: Date? = nil,
        crashReportId: String? = nil,
        coldStart: Bool = false,
        cleanExit: Bool = false,
        appTerminated: Bool = false) {

        self.id = id
        self.state = state.rawValue
        self.processId = processId
        self.traceId = traceId
        self.spanId = spanId
        self.startTime = startTime
        self.endTime = endTime
        self.lastHeartbeatTime = lastHeartbeatTime ?? startTime
        self.crashReportId = crashReportId
        self.coldStart = coldStart
        self.cleanExit = cleanExit
        self.appTerminated = appTerminated
    }
}

extension SessionRecord {
    struct Schema {
        static var id: Column { Column("id") }
        static var state: Column { Column("state") }
        static var processId: Column { Column("process_id") }
        static var traceId: Column { Column("trace_id") }
        static var spanId: Column { Column("span_id") }
        static var startTime: Column { Column("start_time") }
        static var endTime: Column { Column("end_time") }
        static var lastHeartbeatTime: Column { Column("last_heartbeat_time") }
        static var crashReportId: Column { Column("crash_report_id") }
        static var coldStart: Column { Column("cold_start") }
        static var cleanExit: Column { Column("clean_exit") }
        static var appTerminated: Column { Column("app_terminated") }
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

            t.primaryKey(Schema.id.name, .text).notNull()

            t.column(Schema.state.name, .text).notNull()
            t.column(Schema.processId.name, .text).notNull()
            t.column(Schema.traceId.name, .text).notNull()
            t.column(Schema.spanId.name, .text).notNull()

            t.column(Schema.startTime.name, .datetime).notNull()
            t.column(Schema.endTime.name, .datetime)
            t.column(Schema.lastHeartbeatTime.name, .datetime).notNull()

            t.column(Schema.coldStart.name, .boolean)
                .notNull()
                .defaults(to: false)

            t.column(Schema.cleanExit.name, .boolean)
                .notNull()
                .defaults(to: false)

            t.column(Schema.appTerminated.name, .boolean)
                .notNull()
                .defaults(to: false)

            t.column(Schema.crashReportId.name, .text)
        }
    }
}

extension SessionRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}
