//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

class SessionRecordTests: XCTestCase {

    let testOptions = EmbraceStorage.Options(baseUrl: URL(fileURLWithPath: NSTemporaryDirectory()), fileName: "test.sqlite")

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: testOptions.filePath!) {
            try FileManager.default.removeItem(atPath: testOptions.filePath!)
        }
    }

    override func tearDownWithError() throws {

    }

    func test_tableSchema() throws {
        // given new storage
        let storage = try EmbraceStorage(options: testOptions)

        let expectation = XCTestExpectation()

        // then the table and its colums should be correct
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(SessionRecord.databaseTableName))

            let columns = try db.columns(in: SessionRecord.databaseTableName)
            XCTAssertEqual(columns.count, 9, "Column count does not match expectation. Did you add/remove a column?")

            // id
            let idColumn = columns.first(where: { $0.name == "id" })
            if let idColumn = idColumn {
                XCTAssertEqual(idColumn.type, "TEXT")
                XCTAssert(idColumn.isNotNull)
                XCTAssert(try db.table(SessionRecord.databaseTableName, hasUniqueKey: ["id"]))
            } else {
                XCTAssert(false, "id column not found!")
            }

            // state
            let stateTimeColumn = columns.first(where: { $0.name == "state" })
            if let stateTimeColumn = stateTimeColumn {
                XCTAssertEqual(stateTimeColumn.type, "TEXT")
                XCTAssert(stateTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "state column not found!")
            }

            // process_id
            let processIdColumn = columns.first(where: { $0.name == "process_id" })
            if let processIdColumn = processIdColumn {
                XCTAssertEqual(processIdColumn.type, "TEXT")
                XCTAssert(processIdColumn.isNotNull)
            } else {
                XCTAssert(false, "process_id column not found!")
            }

            // start_time
            let startTimeColumn = columns.first(where: { $0.name == "start_time" })
            if let startTimeColumn = startTimeColumn {
                XCTAssertEqual(startTimeColumn.type, "DATETIME")
                XCTAssert(startTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "start_time column not found!")
            }

            // end_time
            let endTimeColumn = columns.first(where: { $0.name == "end_time" })
            if let endTimeColumn = endTimeColumn {
                XCTAssertEqual(endTimeColumn.type, "DATETIME")
            } else {
                XCTAssert(false, "end_time column not found!")
            }

            // crash_report_id
            let crashReportIdColumn = columns.first(where: { $0.name == "crash_report_id" })
            if let crashReportIdColumn = crashReportIdColumn {
                XCTAssertEqual(crashReportIdColumn.type, "TEXT")
            } else {
                XCTAssert(false, "crash_report_id column not found!")
            }

            // cold_start
            let coldStartColumn = columns.first(where: { $0.name == "cold_start" })
            if let coldStartColumn = coldStartColumn {
                XCTAssertEqual(coldStartColumn.type, "BOOLEAN")
                XCTAssertTrue(coldStartColumn.isNotNull)
                XCTAssertEqual(coldStartColumn.defaultValueSQL, "0")
            } else {
                XCTAssert(false, "cold_start column not found!")
            }

            // clean_exit
            let cleanExitColumn = columns.first(where: { $0.name == "clean_exit" })
            if let cleanExitColumn = cleanExitColumn {
                XCTAssertEqual(cleanExitColumn.type, "BOOLEAN")
                XCTAssertTrue(cleanExitColumn.isNotNull)
                XCTAssertEqual(cleanExitColumn.defaultValueSQL, "0")
            } else {
                XCTAssert(false, "clean_exit column not found!")
            }

            // app_terminated
            let appTerminatedColumn = columns.first(where: { $0.name == "app_terminated" })
            if let appTerminatedColumn = appTerminatedColumn {
                XCTAssertEqual(appTerminatedColumn.type, "BOOLEAN")
                XCTAssertTrue(appTerminatedColumn.isNotNull)
                XCTAssertEqual(appTerminatedColumn.defaultValueSQL, "0")
            } else {
                XCTAssert(false, "app_terminated column not found!")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addSession() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let session = try storage.addSession(id: "id", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)
        XCTAssertNotNil(session)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try session.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_upsertSession() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let session = SessionRecord(id: "id", state: .foreground, processId: ProcessIdentifier.current, startTime: Date())
        try storage.upsertSession(session)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try session.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchSession() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let original = try storage.addSession(id: "id", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)

        // when fetching the session
        let session = try storage.fetchSession(id: "id")

        // then the session should be valid
        XCTAssertNotNil(session)
        XCTAssertEqual(original, session)
    }

    func test_updateSessionEndTime() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session with nil endTime
        let original = try storage.addSession(id: "id", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)
        XCTAssertNil(original.endTime)

        // when updating the session endtime
        let session = try storage.updateSession(id: "id", endTime: Date(timeIntervalSinceNow: 10))

        // then the session should be valid and be updated in storage
        let expectation = XCTestExpectation()
        if let session = session {
            try storage.dbQueue.read { db in
                XCTAssert(try session.exists(db))
                XCTAssertNotNil(session.endTime)
                expectation.fulfill()
            }
        } else {
            XCTAssert(false, "session not found in storage!")
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_updateSessionCrashReportId() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session with nil endTime
        let original = try storage.addSession(id: "id", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)
        XCTAssertNil(original.endTime)

        // when updating the session endtime
        let session = try storage.updateSession(id: "id", crashReportId: "crashReportId")

        // then the session should be valid and be updated in storage
        let expectation = XCTestExpectation()
        if let session = session {
            try storage.dbQueue.read { db in
                XCTAssert(try session.exists(db))
                XCTAssertEqual(session.crashReportId, "crashReportId")
                expectation.fulfill()
            }
        } else {
            XCTAssert(false, "session not found in storage!")
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_finishedSessionsCount() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted sessions
        _ = try storage.addSession(id: "id1", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)
        _ = try storage.addSession(id: "id2", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))
        _ = try storage.addSession(id: "id3", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))

        // then the finished session count should be correct
        let count = try storage.finishedSessionsCount()
        XCTAssertEqual(count, 2)
    }

    func test_fetchFinishedSessions() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted sessions
        let session1 = try storage.addSession(id: "id1", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)
        let session2 = try storage.addSession(id: "id2", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))
        let session3 = try storage.addSession(id: "id3", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))

        // when fetching the finished sessions
        let sessions = try storage.fetchFinishedSessions()

        // then the fetched sessions are valid
        XCTAssertFalse(sessions.contains(session1))
        XCTAssert(sessions.contains(session2))
        XCTAssert(sessions.contains(session3))
    }

    func test_fetchLatestSesssion() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted sessions
        _ = try storage.addSession(id: "id1", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(), endTime: nil)
        _ = try storage.addSession(id: "id2", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(timeIntervalSinceNow: 10), endTime: nil)
        let session3 = try storage.addSession(id: "id3", state: .foreground, processId: ProcessIdentifier.current, startTime: Date(timeIntervalSinceNow: 20), endTime: nil)

        // when fetching the latest session
        let session = try storage.fetchLatestSesssion()

        // then the fetched session is valid
        XCTAssertEqual(session, session3)
    }
}
