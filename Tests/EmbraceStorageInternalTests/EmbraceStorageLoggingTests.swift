//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommonInternal

@testable import EmbraceStorageInternal

class EmbraceStorageLoggingTests: XCTestCase {
    var sut: EmbraceStorage!

    override func setUpWithError() throws {
        sut = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        try sut.teardown()
    }

    // MARK: - CreateLog

    func test_createLog_shouldCreateItInDataBase() throws {
        let expectation = expectation(description: #function)
        let log = LogRecord(identifier: .random,
                            processIdentifier: .random,
                            severity: .info,
                            body: "log message",
                            attributes: .empty()
        )

        sut.create(log) { result in
            if case let Result.success(persistedLog) = result {
                XCTAssertEqual(log.identifier, persistedLog.identifier)
            } else {
                XCTFail("Couldn't persist log")
            }

            do {
                try sut.dbQueue.read { db in
                    XCTAssertTrue(try log.exists(db))
                    expectation.fulfill()
                }
            } catch let exception {
                XCTFail(exception.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    // MARK: - GetAll

    func testFilledDb_getAll_shouldGetAlllogsFromDatabase() throws {
        let logs: [LogRecord] = [.infoLog(), .infoLog(), .infoLog(), .infoLog()]
        givenDatabase(withLogs: logs)

        let result = try sut.getAll()

        XCTAssertEqual(result, logs)
    }

    func testEmptyDb_getAll_shouldGetAlllogsFromDatabase() throws {
        givenDatabase(withLogs: [])

        let result = try sut.getAll()

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Fetch All Excluding Process Identifier

    func test_fetchAllExcludingProcessIdentifier_shouldFilterLogsProperly() throws {
        let pid = ProcessIdentifier(value: 12345)
        let log1 = LogRecord.infoLog(pid: pid)
        let log2 = LogRecord.infoLog(pid: pid)
        givenDatabase(withLogs: [
            .infoLog(),
            log1,
            .infoLog(),
            log2
        ])

        let result = try sut.fetchAll(excludingProcessIdentifier: pid)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(!result.contains(where: { $0.processIdentifier == pid }))
    }

    // MARK: - RemoveAllLogs

    func testFilledDb_removeAllLogs_shouldCleanDb() throws {
        let expectation = expectation(description: #function)
        let logs: [LogRecord] = [.infoLog(), .infoLog(), .infoLog()]
        givenDatabase(withLogs: logs)

        try sut.removeAllLogs()

        try sut.dbQueue.read { db in
            try logs.forEach {
                XCTAssertFalse(try $0.exists(db))
            }
            expectation.fulfill()
        }
        wait(for: [expectation])
    }

    // MARK: - Remove Specific Logs

    func testFilledDb_removeSpecificLog_shouldDeleteJustTheSpecificLog() throws {
        let expectation = expectation(description: #function)
        let firstLogToDelete: LogRecord = .infoLog()
        let secondLogToDelete: LogRecord = .infoLog()
        let nonDeletedLog: LogRecord = .infoLog()
        let logs: [LogRecord] = [
            firstLogToDelete,
            secondLogToDelete,
            nonDeletedLog
        ]

        givenDatabase(withLogs: logs)

        try sut.remove(logs: [
            firstLogToDelete,
            secondLogToDelete
        ])

        try sut.dbQueue.read { db in
            XCTAssertFalse(try firstLogToDelete.exists(db))
            XCTAssertFalse(try secondLogToDelete.exists(db))
            XCTAssertTrue(try nonDeletedLog.exists(db))
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
}

private extension EmbraceStorageLoggingTests {
    func givenDatabase(withLogs logs: [LogRecord]) {
        do {
            try logs.forEach { log in
                try sut.dbQueue.write { db in
                    try log.insert(db)
                }
            }
        } catch let exception {
            XCTFail("Couldn't create logs: \(exception.localizedDescription)")
        }
    }
}

extension LogRecord {
    static func infoLog(withId id: UUID = UUID(), pid: ProcessIdentifier = .random) -> LogRecord {
        .init(identifier: LogIdentifier.init(value: id),
              processIdentifier: pid,
              severity: .info,
              body: "a log message",
              attributes: .empty())
    }
}

extension LogRecord: Equatable {
    public static func == (lhs: LogRecord, rhs: LogRecord) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
