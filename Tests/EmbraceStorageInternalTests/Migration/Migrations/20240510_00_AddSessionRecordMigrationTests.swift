//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorageInternal
import GRDB

final class _0240510_AddSessionRecordMigrationTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb(runMigrations: false)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_identifier() {
        let migration = AddSessionRecordMigration()
        XCTAssertEqual(migration.identifier, "CreateSessionRecordTable")
    }

    func test_perform_createsTableWithCorrectSchema() throws {
        let migration = AddSessionRecordMigration()

        try storage.dbQueue.write { db in
            try migration.perform(db)
        }

        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(SessionRecord.databaseTableName))

            XCTAssert(try db.table(SessionRecord.databaseTableName, hasUniqueKey: [SessionRecord.Schema.id.name]))

            let columns = try db.columns(in: SessionRecord.databaseTableName)
            XCTAssertEqual(columns.count, 12)

            // id
            let idColumn = columns.first { info in
                info.name == SessionRecord.Schema.id.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(idColumn)

            // state
            let stateTimeColumn = columns.first { info in
                info.name == SessionRecord.Schema.state.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(stateTimeColumn)

            // process_id
            let processIdColumn = columns.first { info in
                info.name == SessionRecord.Schema.processId.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(processIdColumn)

            // trace_id
            let traceIdColumn = columns.first { info in
                info.name == SessionRecord.Schema.traceId.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(traceIdColumn)

            // span_id
            let spanIdColumn = columns.first { info in
                info.name == SessionRecord.Schema.spanId.name &&
                info.type == "TEXT" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(spanIdColumn)

            // start_time
            let startTimeColumn = columns.first { info in
                info.name == SessionRecord.Schema.startTime.name &&
                info.type == "DATETIME" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(startTimeColumn)

            // end_time
            let endTimeColumn = columns.first { info in
                info.name == SessionRecord.Schema.endTime.name &&
                info.type == "DATETIME" &&
                info.isNotNull == false
            }
            XCTAssertNotNil(endTimeColumn)

            // last_heartbeat_time
            let lastHeartbeatTimeColumn = columns.first { info in
                info.name == SessionRecord.Schema.lastHeartbeatTime.name &&
                info.type == "DATETIME" &&
                info.isNotNull == true
            }
            XCTAssertNotNil(lastHeartbeatTimeColumn)

            // cold_start
            let coldStartColumn = columns.first { info in
                info.name == SessionRecord.Schema.coldStart.name &&
                info.type == "BOOLEAN" &&
                info.isNotNull == true &&
                info.defaultValueSQL == "0"
            }
            XCTAssertNotNil(coldStartColumn)

            // clean_exit
            let cleanExitColumn = columns.first { info in
                info.name == SessionRecord.Schema.cleanExit.name &&
                info.type == "BOOLEAN" &&
                info.isNotNull == true &&
                info.defaultValueSQL == "0"
            }
            XCTAssertNotNil(cleanExitColumn)

            // app_terminated
            let appTerminatedColumn = columns.first { info in
                info.name == SessionRecord.Schema.appTerminated.name &&
                info.type == "BOOLEAN" &&
                info.isNotNull == true &&
                info.defaultValueSQL == "0"
            }
            XCTAssertNotNil(appTerminatedColumn)

            // crash_report_id
            let crashReportIdColumn = columns.first { info in
                info.name == SessionRecord.Schema.crashReportId.name &&
                info.type == "TEXT" &&
                info.isNotNull == false
            }
            XCTAssertNotNil(crashReportIdColumn)
        }
    }

}
