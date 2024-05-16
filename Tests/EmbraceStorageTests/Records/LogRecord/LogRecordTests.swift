//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

class LogRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_tableSchema() throws {
        XCTAssertEqual(LogRecord.databaseTableName, "logs")

        // then the table and its colums should be correct
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(LogRecord.databaseTableName))

            let columns = try db.columns(in: LogRecord.databaseTableName)

            XCTAssert(try db.table(
                LogRecord.databaseTableName,
                hasUniqueKey: ["identifier"]
            ))

            // identifier
            if let idColumn = columns.first(where: { $0.name == "identifier" }) {
                XCTAssertEqual(idColumn.type, "TEXT")
                XCTAssert(idColumn.isNotNull)
            } else {
                XCTAssert(false, "identifier column not found!")
            }

            // process id
            if let idColumn = columns.first(where: { $0.name == "process_identifier" }) {
                XCTAssertEqual(idColumn.type, "INTEGER")
                XCTAssert(idColumn.isNotNull)
            } else {
                XCTAssert(false, "process_identifier column not found!")
            }

            // severity
            if let logSeverityColumn = columns.first(where: { $0.name == "severity" }) {
                XCTAssertEqual(logSeverityColumn.type, "INTEGER")
                XCTAssert(logSeverityColumn.isNotNull)
            } else {
                XCTAssert(false, "severity not found!")
            }

            // body
            if let messageColumn = columns.first(where: { $0.name == "body" }) {
                XCTAssertEqual(messageColumn.type, "TEXT")
                XCTAssert(messageColumn.isNotNull)
            } else {
                XCTAssert(false, "body column not found!")
            }

            // timestamp
            if let dateColumn = columns.first(where: { $0.name == "timestamp" }) {
                XCTAssertEqual(dateColumn.type, "DATETIME")
                XCTAssert(dateColumn.isNotNull)
            } else {
                XCTAssert(false, "timestamp column not found!")
            }

            // attributes
            if let dateColumn = columns.first(where: { $0.name == "attributes" }) {
                XCTAssertEqual(dateColumn.type, "TEXT")
                XCTAssert(dateColumn.isNotNull)
            } else {
                XCTAssert(false, "attributes column not found!")
            }
        }
    }
}
