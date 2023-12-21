//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

class ResourceRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_tableSchema() throws {
        let expectation = XCTestExpectation()

        // then the table and its colums should be correct
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(ResourceRecord.databaseTableName))

            let columns = try db.columns(in: ResourceRecord.databaseTableName)

            XCTAssert(try db.table(
                ResourceRecord.databaseTableName,
                hasUniqueKey: ["key", "resource_type", "resource_type_id"]
            ))

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
        XCTAssertEqual(resource.value, .string("bar"))
    }

    func test_init_process_convenience() throws {
        let processId = ProcessIdentifier.random
        let resource = ResourceRecord(key: "foo", value: "bar", processIdentifier: processId)

        XCTAssertEqual(resource.resourceType, .process)
        XCTAssertEqual(resource.resourceTypeId, processId.hex)
        XCTAssertEqual(resource.key, "foo")
        XCTAssertEqual(resource.value, .string("bar"))
    }

    func test_init_permanent_convenience() throws {
        let resource = ResourceRecord(key: "foo", value: "bar")

        XCTAssertEqual(resource.resourceType, .permanent)
        XCTAssertEqual(resource.resourceTypeId, "")
        XCTAssertEqual(resource.key, "foo")
        XCTAssertEqual(resource.value, .string("bar"))
    }

    func test_addResource() throws {
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

            // sort value alphabetically to assert known order
            XCTAssertEqual(
                try ResourceRecord.fetchAll(db)
                    .compactMap { $0.stringValue }
                    .sorted(),  // sort value alphabetically to assert known order
                ["Chet", "Delilah", "Frank", "Spot", "Steven"]
            )
        }
    }

    func test_fetchAllResources() throws {
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

    func test_fetchAllResourceForSession() throws {
        let testSessionId = SessionIdentifier(string: "4DF21070-D774-4282-9AFC-2D0D9D223255")!
        let testProcessId = ProcessIdentifier.random

        try storage.addSession(
            id: testSessionId,
            state: .foreground,
            processId: testProcessId,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        try storage.addResource(key: "test", value: "test", resourceType: .session, resourceTypeId: "123654852")
        try storage.addResource(key: "test", value: "test", resourceType: .process, resourceTypeId: "1236s4852")

        let originals = [
            // given inserted session
            try storage.addResource(
                key: "test1",
                value: "test1",
                resourceType: .process,
                resourceTypeId: testProcessId.hex
            ),
            try storage.addResource(
                key: "test2",
                value: "test2",
                resourceType: .process,
                resourceTypeId: testProcessId.hex
            ),
            try storage.addResource(
                key: "test3",
                value: "test3",
                resourceType: .session,
                resourceTypeId: testSessionId.toString
            ),
            try storage.addResource(
                key: "test4",
                value: "test4",
                resourceType: .session,
                resourceTypeId: testSessionId.toString
            ),
            try storage.addResource(
                key: "test5",
                value: "test5",
                resourceType: .permanent
            )
        ]

        // when fetching the session
        let resources = try storage.fetchAllResourceForSession(sessionId: testSessionId)

        // then the session should be valid
        XCTAssertNotNil(resources)
        XCTAssertEqual(originals, resources)
    }
}
