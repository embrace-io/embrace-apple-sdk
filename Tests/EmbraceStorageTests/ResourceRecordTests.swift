//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

class ResourceRecordTests: XCTestCase {

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
            XCTAssert(try db.tableExists(ResourceRecord.databaseTableName))

            let columns = try db.columns(in: ResourceRecord.databaseTableName)

            // id
            let keyColumn = columns.first(where: { $0.name == "key" })
            if let keyColumn = keyColumn {
                XCTAssertEqual(keyColumn.type, "TEXT")
                XCTAssert(keyColumn.isNotNull)
                XCTAssert(try db.table(ResourceRecord.databaseTableName, hasUniqueKey: ["key"]))
            } else {
                XCTAssert(false, "key column not found!")
            }

            // state
            let valueColumn = columns.first(where: { $0.name == "value" })
            if let valueColumn = valueColumn {
                XCTAssertEqual(valueColumn.type, "TEXT")
                XCTAssert(valueColumn.isNotNull)
            } else {
                XCTAssert(false, "value column not found!")
            }

            // start_time
            let collectedAtColumn = columns.first(where: { $0.name == "collected_at" })
            if let collectedAtColumn = collectedAtColumn {
                XCTAssertEqual(collectedAtColumn.type, "DATETIME")
                XCTAssert(collectedAtColumn.isNotNull)
            } else {
                XCTAssert(false, "collected_at column not found!")
            }

            // crash_report_id
            let resourceTypeColumn = columns.first(where: { $0.name == "resource_type" })
            if let resourceTypeColumn = resourceTypeColumn {
                XCTAssertEqual(resourceTypeColumn.type, "TEXT")
            } else {
                XCTAssert(false, "resource_type column not found!")
            }

            let resourceTypeIdColumn = columns.first(where: { $0.name == "resource_type_id" })
            if let resourceTypeIdColumn = resourceTypeIdColumn {
                XCTAssertEqual(resourceTypeIdColumn.type, "TEXT")
            } else {
                XCTAssert(false, "resource_type_id column not found!")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addResource() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let resource = try storage.addResource(key: "test", value: "test", resourceType: .permanent)
        XCTAssertNotNil(resource)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try resource.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_upsertResource() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let resource = ResourceRecord(key: "test", value: "test", resourceType: .permanent)
        try storage.upsertResource(resource)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try resource.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchResource() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let original = try storage.addResource(key: "test", value: "test", resourceType: .permanent)

        // when fetching the session
        let resource = try storage.fetchResource(key: "test")

        // then the session should be valid
        XCTAssertNotNil(resource)
        XCTAssertEqual(original, resource)
    }

    func test_fetchAllResources() throws {
        let storage = try EmbraceStorage(options: testOptions)

        var originals = [ResourceRecord]()

        // given inserted session
        originals.append(try storage.addResource(key: "test", value: "test", resourceType: .permanent))
        originals.append(try storage.addResource(key: "test1", value: "test1", resourceType: .permanent))
        originals.append(try storage.addResource(key: "test2", value: "test2", resourceType: .permanent))
        originals.append(try storage.addResource(key: "test3", value: "test3", resourceType: .permanent))
        // when fetching the session
        let resources = try storage.fetchAllResources()

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }

    func test_fetchPermanentResources() throws {
        let storage = try EmbraceStorage(options: testOptions)

        var originals = [ResourceRecord]()
        // given inserted session
        originals.append(try storage.addResource(key: "test", value: "test", resourceType: .permanent))
        originals.append(try storage.addResource(key: "test2", value: "test2", resourceType: .permanent))

        // when fetching the session
        let resources = try storage.fetchAllPermanentResources()

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }

    func test_fetchResourceBySessionId() throws {
        let storage = try EmbraceStorage(options: testOptions)

        var originals = [ResourceRecord]()
        // given inserted session
        originals.append(try storage.addResource(key: "test", value: "test", resourceType: .session, resourceTypeId: "3547A348-4AF6-A7B0-4EA35A70CBC"))
        originals.append(try storage.addResource(key: "test2", value: "test2", resourceType: .session, resourceTypeId: "3547A348-4AF6-A7B0-4EA35A70CBC"))

        // when fetching the session
        let resources = try storage.fetchResource(sessionId: "3547A348-4AF6-A7B0-4EA35A70CBC")

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }

    func test_fetchResourceByProcessId() throws {
        let storage = try EmbraceStorage(options: testOptions)

        var originals = [ResourceRecord]()
        // given inserted session
        originals.append(try storage.addResource(key: "test", value: "test", resourceType: .process, resourceTypeId: "123654852"))
        originals.append(try storage.addResource(key: "test2", value: "test2", resourceType: .process, resourceTypeId: "123654852"))

        // when fetching the session
        let resources = try storage.fetchResource(pId: 123654852)

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }

    func test_fetchAllResourceForSession() throws {
        let storage = try EmbraceStorage(options: testOptions)

        let testSessionId = UUID()
        let testProcessId = UUID()

        try storage.addSession(id: testSessionId.uuidString, state: .foreground, processId: testProcessId, startTime: Date())

        try storage.addResource(key: "test", value: "test", resourceType: .session, resourceTypeId: "123654852")
        try storage.addResource(key: "test", value: "test", resourceType: .process, resourceTypeId: "1236s4852")

        var originals = [ResourceRecord]()
        // given inserted session
        originals.append(try storage.addResource(key: "test1", value: "test1", resourceType: .process, resourceTypeId: testProcessId.uuidString))
        originals.append(try storage.addResource(key: "test2", value: "test2", resourceType: .process, resourceTypeId: testProcessId.uuidString))
        originals.append(try storage.addResource(key: "test3", value: "test3", resourceType: .session, resourceTypeId: testSessionId.uuidString))
        originals.append(try storage.addResource(key: "test4", value: "test4", resourceType: .session, resourceTypeId: testSessionId.uuidString))
        originals.append(try storage.addResource(key: "test5", value: "test5", resourceType: .permanent))

        // when fetching the session
        let resources = try storage.fetchAllResourceForSession(sessionId: testSessionId.uuidString)

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }
}
