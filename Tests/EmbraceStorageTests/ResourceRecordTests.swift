//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

class ResourceRecordTests: XCTestCase {

    let testOptions = EmbraceStorage.Options(named: #file)

    override func setUpWithError() throws {

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

            XCTAssert(try db.table(ResourceRecord.databaseTableName, hasUniqueKey: ["key", "resource_type", "resource_type_id"]))

            // id
            let keyColumn = columns.first(where: { $0.name == "key" })
            if let keyColumn = keyColumn {
                XCTAssertEqual(keyColumn.type, "TEXT")
                XCTAssert(keyColumn.isNotNull)
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

    func test_init_session_convenience() throws {
        let sessionId = SessionIdentifier.random
        let resource = ResourceRecord(key: "foo", value: "bar", sessionId: sessionId)

        XCTAssertEqual(resource.resourceType, .session)
        XCTAssertEqual(resource.resourceTypeId, sessionId.toString)
        XCTAssertEqual(resource.key, "foo")
        XCTAssertEqual(resource.value, "bar")
    }

    func test_init_process_convenience() throws {
        let processId = ProcessIdentifier.random
        let resource = ResourceRecord(key: "foo", value: "bar", processIdentifier: processId)

        XCTAssertEqual(resource.resourceType, .process)
        XCTAssertEqual(resource.resourceTypeId, processId.hex)
        XCTAssertEqual(resource.key, "foo")
        XCTAssertEqual(resource.value, "bar")
    }

    func test_init_permanent_convenience() throws {
        let resource = ResourceRecord(key: "foo", value: "bar")

        XCTAssertEqual(resource.resourceType, .permanent)
        XCTAssertEqual(resource.resourceTypeId, "")
        XCTAssertEqual(resource.key, "foo")
        XCTAssertEqual(resource.value, "bar")
    }

    func test_addResource() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let resource = try storage.addResource(key: "test", value: "test", resourceType: .permanent)
        XCTAssertNotNil(resource)

        // then record should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try resource.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_upsertResource() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted record
        let resource = ResourceRecord(key: "test", value: "test")
        try storage.upsertResource(resource)

        let change = ResourceRecord(key: "test", value: "change")
        try storage.upsertResource(change)

        // then record should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try ResourceRecord.fetchCount(db), 1)
            XCTAssert(try resource.exists(db))
            XCTAssert(try change.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_upsertResources() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted records
        try storage.upsertResources([
            ResourceRecord(key: "cat.name", value: "Chet"),
            ResourceRecord(key: "dog.name", value: "Spunky"),
            ResourceRecord(key: "pig.name", value: "Delilah"),
            ResourceRecord(key: "horse.name", value: "Frank")
        ])

        try storage.upsertResources([
            ResourceRecord(key: "dog.name", value: "Spot"),
            ResourceRecord(key: "frog.name", value: "Steven")
        ])

        // then record should exist in storage
        try storage.dbQueue.read { db in
            XCTAssertEqual(try ResourceRecord.fetchCount(db), 5)
            XCTAssertEqual(
                try ResourceRecord.fetchAll(db).map(\.value).sorted(), // sort value alphabetically to assert known order
                ["Chet", "Delilah", "Frank", "Spot", "Steven"]
            )
        }
    }

    func test_fetchResource() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted record
        let original = try storage.addResource(key: "test", value: "test", resourceType: .permanent)

        // when fetching the record
        let resource = try storage.fetchResource(key: "test")

        // then the record should be valid
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
        let testProcessId = ProcessIdentifier.random

        try storage.addSession(id: testSessionId.uuidString, state: .foreground, processId: testProcessId, startTime: Date())

        try storage.addResource(key: "test", value: "test", resourceType: .session, resourceTypeId: "123654852")
        try storage.addResource(key: "test", value: "test", resourceType: .process, resourceTypeId: "1236s4852")

        var originals = [
            // given inserted session
            try storage.addResource(key: "test1", value: "test1", resourceType: .process, resourceTypeId: String(testProcessId.value)),
            try storage.addResource(key: "test2", value: "test2", resourceType: .process, resourceTypeId: String(testProcessId.value)),
            try storage.addResource(key: "test3", value: "test3", resourceType: .session, resourceTypeId: testSessionId.uuidString),
            try storage.addResource(key: "test4", value: "test4", resourceType: .session, resourceTypeId: testSessionId.uuidString),
            try storage.addResource(key: "test5", value: "test5", resourceType: .permanent)
        ]

        // when fetching the session
        let resources = try storage.fetchAllResourceForSession(sessionId: testSessionId.uuidString)

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }
}
