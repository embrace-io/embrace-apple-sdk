//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceStorageInternal

class EmbraceStorageLoggingTests: XCTestCase {
    var sut: EmbraceStorage!

    override func setUpWithError() throws {
        sut = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        sut.coreData.destroy()
    }

    // MARK: - CreateLog

    func test_createLog_shouldCreateItInDataBase() throws {
        let id = EmbraceIdentifier.random
        sut.saveLog(
            MockLog(
                id: id.stringValue,
                body: "log message",
                sessionId: .random,
                processId: .random
            )
        )

        let logs: [LogRecord] = sut.fetchAll()
        XCTAssertEqual(logs.count, 1)
        XCTAssertNotNil(logs.first(where: { $0.id == id.stringValue }))
    }

    // MARK: - Fetch All Excluding Process Identifier

    func test_fetchAllExcludingProcessIdentifier_shouldFilterLogsProperly() throws {
        let pid = EmbraceIdentifier(stringValue: "12345")
        createInfoLog(pid: pid)
        createInfoLog()
        createInfoLog(pid: pid)
        createInfoLog()

        let result = sut.fetchAllLogs(excludingProcessIdentifier: pid)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(!result.contains(where: { $0.processId == pid }))
    }

    // MARK: - Remove Specific Logs

    func testFilledDb_removeSpecificLog_shouldDeleteJustTheSpecificLog() throws {
        let uuid1 = UUID()
        let firstLogToDelete = createInfoLog(withId: uuid1)

        let uuid2 = UUID()
        let secondLogToDelete = createInfoLog(withId: uuid2)

        let uuid3 = UUID()
        createInfoLog(withId: uuid3)

        sut.remove(logs: [
            firstLogToDelete,
            secondLogToDelete
        ])

        let logs: [LogRecord] = sut.fetchAll()
        XCTAssertEqual(logs.count, 1)
        XCTAssertNil(logs.first(where: { $0.id == uuid1.withoutHyphen }))
        XCTAssertNil(logs.first(where: { $0.id == uuid2.withoutHyphen }))
        XCTAssertNotNil(logs.first(where: { $0.id == uuid3.withoutHyphen }))
    }
}

extension EmbraceStorageLoggingTests {
    @discardableResult
    fileprivate func createInfoLog(withId id: UUID = UUID(), pid: EmbraceIdentifier = .random) -> EmbraceLog {

        let log = MockLog(
            id: id.withoutHyphen,
            body: "a log message",
            sessionId: .random,
            processId: pid,
        )

        sut.saveLog(log)

        return log
    }
}
