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
        sut.coreData.destroy()
    }

    // MARK: - CreateLog

    func test_createLog_shouldCreateItInDataBase() throws {
        let id = LogIdentifier.random
        sut.createLog(
            id: id,
            processId: .random,
            severity: .info,
            body: "log message",
            attributes: .empty()
        )

        let logs: [LogRecord] = sut.fetchAll()
        XCTAssertEqual(logs.count, 1)
        XCTAssertNotNil(logs.first(where: { $0.idRaw == id.toString }))
    }

    // MARK: - Fetch All Excluding Process Identifier

    func test_fetchAllExcludingProcessIdentifier_shouldFilterLogsProperly() throws {
        let pid = ProcessIdentifier(value: 12345)
        createInfoLog(pid: pid)
        createInfoLog()
        createInfoLog(pid: pid)
        createInfoLog()

        let result = sut.fetchAll(excludingProcessIdentifier: pid)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(!result.contains(where: { $0.processIdRaw == pid.hex }))
    }

    // MARK: - RemoveAllLogs

    func testFilledDb_removeAllLogs_shouldCleanDb() throws {
        createInfoLog()
        createInfoLog()
        createInfoLog()

        sut.removeAllLogs()

        let logs: [LogRecord] = sut.fetchAll()
        XCTAssertEqual(logs.count, 0)
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
        XCTAssertNil(logs.first(where: { $0.idRaw == uuid1.withoutHyphen }))
        XCTAssertNil(logs.first(where: { $0.idRaw == uuid2.withoutHyphen }))
        XCTAssertNotNil(logs.first(where: { $0.idRaw == uuid3.withoutHyphen }))
    }
}

private extension EmbraceStorageLoggingTests {
    @discardableResult
    func createInfoLog(withId id: UUID = UUID(), pid: ProcessIdentifier = .random) -> LogRecord {
        return sut.createLog(
            id: LogIdentifier.init(value: id),
            processId: pid,
            severity: .info,
            body: "a log message",
            attributes: .empty()
        )
    }
}
