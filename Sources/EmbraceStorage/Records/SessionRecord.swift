//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import GRDB

/// Represents a session in the storage
public struct SessionRecord: Codable {
    public var id: SessionId
    public var processId: ProcessIdentifier
    public var state: String
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

    public init(id: SessionId, state: SessionState, processId: ProcessIdentifier, startTime: Date, endTime: Date? = nil, lastHeartbeatTime: Date? = nil, crashReportId: String? = nil, coldStart: Bool = false, cleanExit: Bool = false, appTerminated: Bool = false) {

        self.id = id
        self.state = state.rawValue
        self.processId = processId
        self.startTime = startTime
        self.endTime = endTime
        self.lastHeartbeatTime = lastHeartbeatTime ?? startTime
        self.crashReportId = crashReportId
        self.coldStart = coldStart
        self.cleanExit = cleanExit
        self.appTerminated = appTerminated
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

            t.column("state", .text).notNull()
            t.column("process_id", .text).notNull()
            t.column("start_time", .datetime).notNull()
            t.column("end_time", .datetime)
            t.column("last_heartbeat_time", .datetime).notNull()

            t.column("cold_start", .boolean)
                .notNull()
                .defaults(to: false)

            t.column("clean_exit", .boolean)
                .notNull()
                .defaults(to: false)

            t.column("app_terminated", .boolean)
                .notNull()
                .defaults(to: false)

            t.column("crash_report_id", .text)
        }
    }
}

extension SessionRecord: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}
