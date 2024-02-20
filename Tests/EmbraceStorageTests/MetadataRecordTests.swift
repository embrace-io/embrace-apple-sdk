//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

// swiftlint:disable type_body_length file_length

class MetadataRecordTests: XCTestCase {
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
            XCTAssert(try db.tableExists(MetadataRecord.databaseTableName))

            // primary key
            XCTAssert(try db.table(
                MetadataRecord.databaseTableName,
                hasUniqueKey: [
                    MetadataRecord.Schema.key.name,
                    MetadataRecord.Schema.type.name,
                    MetadataRecord.Schema.lifespan.name,
                    MetadataRecord.Schema.lifespanId.name
                ]
            ))

            // column count
            let columns = try db.columns(in: MetadataRecord.databaseTableName)
            XCTAssertEqual(columns.count, 6)

            // id
            let keyColumn = columns.first(where: { $0.name == MetadataRecord.Schema.key.name })
            if let keyColumn = keyColumn {
                XCTAssertEqual(keyColumn.type, "TEXT")
                XCTAssert(keyColumn.isNotNull)
            } else {
                XCTAssert(false, "key column not found!")
            }

            // state
            let valueColumn = columns.first(where: { $0.name == MetadataRecord.Schema.value.name })
            if let valueColumn = valueColumn {
                XCTAssertEqual(valueColumn.type, "TEXT")
                XCTAssert(valueColumn.isNotNull)
            } else {
                XCTAssert(false, "value column not found!")
            }

            // type
            let typeColumn = columns.first(where: { $0.name == MetadataRecord.Schema.type.name })
            if let typeColumn = typeColumn {
                XCTAssertEqual(typeColumn.type, "TEXT")
                XCTAssert(typeColumn.isNotNull)
            } else {
                XCTAssert(false, "type column not found!")
            }

            // collected_at
            let collectedAtColumn = columns.first(where: { $0.name == MetadataRecord.Schema.collectedAt.name })
            if let collectedAtColumn = collectedAtColumn {
                XCTAssertEqual(collectedAtColumn.type, "DATETIME")
                XCTAssert(collectedAtColumn.isNotNull)
            } else {
                XCTAssert(false, "collected_at column not found!")
            }

            // lifepsan
            let lifespanColumn = columns.first(where: { $0.name == MetadataRecord.Schema.lifespan.name })
            if let lifespanColumn = lifespanColumn {
                XCTAssertEqual(lifespanColumn.type, "TEXT")
                XCTAssert(lifespanColumn.isNotNull)
            } else {
                XCTAssert(false, "lifespan column not found!")
            }

            // lifepsan id
            let lifespanIdColumn = columns.first(where: { $0.name == MetadataRecord.Schema.lifespanId.name })
            if let lifespanIdColumn = lifespanIdColumn {
                XCTAssertEqual(lifespanIdColumn.type, "TEXT")
                XCTAssert(lifespanIdColumn.isNotNull)
            } else {
                XCTAssert(false, "lifespan_id column not found!")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addMetadata() throws {
        // given inserted metadata
        let metadata = try storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)
        XCTAssertNotNil(metadata)

        // then the record should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try metadata!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addMetadata_resourceLimit() throws {
        // given limit reached on resources
        for i in 1...storage.options.resourcesLimit {
            try storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .permanent
            )
        }

        // when inserting a new resource
        let resource = try storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)

        // then it should not be inserted
        XCTAssertNil(resource)

        // then the record count should be the limit
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), storage.options.resourcesLimit)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addMetadata_customPropertiesLimit() throws {
        // given limit reached on custom properties
        for i in 1...storage.options.customPropertiesLimit {
            try storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .permanent
            )
        }

        // when inserting a new custom property
        let resource = try storage.addMetadata(key: "test", value: "test", type: .customProperty, lifespan: .permanent)

        // then it should not be inserted
        XCTAssertNil(resource)

        // then the record count should be the limit
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), storage.options.customPropertiesLimit)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addMetadata_resourceLimit_lifespanId() throws {
        // given resources in storage that in total surpass the limit
        // but they correspond to different lifespan ids
        for i in 1...storage.options.resourcesLimit {
            try storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .session,
                lifespanId: i % 2 == 0 ? TestConstants.sessionId.toString : "test"
            )

            try storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .process,
                lifespanId: i % 2 == 0 ? TestConstants.processId.hex : "test"
            )
        }

        // when inserting new resources
        let resource1 = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let resource2 = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // then they should be inserted
        XCTAssertNotNil(resource1)
        XCTAssertNotNil(resource2)

        // then the record count should be the limit
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), storage.options.customPropertiesLimit * 2 + 2)
            XCTAssert(try resource1!.exists(db))
            XCTAssert(try resource2!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addMetadata_customPropertiesLimit_lifespanId() throws {
        // given custom properties in storage that in total surpass the limit
        // but they correspond to different lifespan ids
        for i in 1...storage.options.customPropertiesLimit {
            try storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .session,
                lifespanId: i % 2 == 0 ? TestConstants.sessionId.toString : "test"
            )

            try storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .process,
                lifespanId: i % 2 == 0 ? TestConstants.processId.hex : "test"
            )
        }

        // when inserting new custom properties
        let property1 = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let property2 = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // then they should be inserted
        XCTAssertNotNil(property1)
        XCTAssertNotNil(property2)

        // then the record count should be the limit
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), storage.options.customPropertiesLimit * 2 + 2)
            XCTAssert(try property1!.exists(db))
            XCTAssert(try property2!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addMetadata_requiredResource() throws {
        // given limit reached on resources and custom properties
        for i in 0...storage.options.resourcesLimit {
            try storage.addMetadata(key: "resource_\(i)", value: "test", type: .resource, lifespan: .permanent)
            try storage.addMetadata(key: "property_\(i)", value: "test", type: .customProperty, lifespan: .permanent)
        }

        // when inserting a new required resource
        let requiredResource = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )

        // then it should be inserted despite the limits
        XCTAssertNotNil(requiredResource)

        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(
                try MetadataRecord.fetchCount(db),
                storage.options.resourcesLimit + storage.options.customPropertiesLimit + 1
            )
            XCTAssert(try requiredResource!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_updateMetadata() throws {
        // given inserted record
        try storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)

        // when updating its value
        try storage.updateMetadata(key: "test", value: "value", type: .resource, lifespan: .permanent)

        // then record should exist in storage with the correct value
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 1)
            let record = try MetadataRecord.fetchOne(db)
            XCTAssertEqual(record!.value, .string("value"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_cleanMetadata() throws {
        // given inserted records
        let metadata1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let metadata2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        let metadata3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        let metadata4 = try storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when cleaning old metadata
        try storage.cleanMetadata(currentSessionId: TestConstants.sessionId, currentProcessId: TestConstants.processId)

        // then only the correct records should be removed
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 2)
            XCTAssert(try metadata1!.exists(db))
            XCTAssertFalse(try metadata2!.exists(db))
            XCTAssert(try metadata3!.exists(db))
            XCTAssertFalse(try metadata4!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_removeMetadata() throws {
        // given inserted record
        let metadata = try storage.addMetadata(
            key: "test",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )

        // when removing it
        try storage.removeMetadata(key: "test", type: .resource, lifespan: .session, lifespanId: "test")

        // then record should not exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 0)
            XCTAssertFalse(try metadata!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_removeAllMetadata_severalLifespans() throws {
        // given inserted records
        let metadata1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        let metadata2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let metadata3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        let metadata4 = try storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .permanent
        )
        let required = try storage.addMetadata(
            key: "test5",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when removing all by type and lifespans
        try storage.removeAllMetadata(type: .resource, lifespans: [.session, .process])

        // then only the correct records should be removed
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 2)
            XCTAssertFalse(try metadata1!.exists(db))
            XCTAssertFalse(try metadata2!.exists(db))
            XCTAssertFalse(try metadata3!.exists(db))
            XCTAssert(try metadata4!.exists(db))
            XCTAssert(try required!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_removeAllMetadata_severalKeys() throws {
        // given inserted records
        let metadata1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let metadata2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let metadata3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let required = try storage.addMetadata(
            key: "test5",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when removing all by keys and lifespan
        try storage.removeAllMetadata(keys: ["test1", "test3", "test5"], lifespan: .process)

        // then only the correct records should be removed
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 2)
            XCTAssertFalse(try metadata1!.exists(db))
            XCTAssert(try metadata2!.exists(db))
            XCTAssertFalse(try metadata3!.exists(db))
            XCTAssert(try required!.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchMetadata() throws {
        // given inserted record
        try storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)

        // when fetching it
        let record = try storage.fetchMetadata(key: "test", type: .resource, lifespan: .permanent)

        // then its correctly fetched
        XCTAssertNotNil(record)
    }

    func test_fetchRequiredPermanentResource() throws {
        // given inserted permanent required resource
        try storage.addMetadata(key: "test", value: "test", type: .requiredResource, lifespan: .permanent)

        // when fetching it
        let record = try storage.fetchRequriedPermanentResource(key: "test")

        // then its correctly fetched
        XCTAssertNotNil(record)
    }

    func test_fetchAllResources() throws {
        // given inserted records
        let resource1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let resource2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )
        let resource3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let property1 = try storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        let property2 = try storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        let property3 = try storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )

        // when fetching all resources
        let resources = try storage.fetchAllResources()

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssert(resources.contains(resource1!))
        XCTAssert(resources.contains(resource2!))
        XCTAssert(resources.contains(resource3!))
        XCTAssertFalse(resources.contains(property1!))
        XCTAssertFalse(resources.contains(property2!))
        XCTAssertFalse(resources.contains(property3!))
    }

    func test_fetchAllCustomProperties() throws {
        // given inserted records
        let resource1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let resource2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )
        let resource3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let property1 = try storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        let property2 = try storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        let property3 = try storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )

        // when fetching all custom properties
        let resources = try storage.fetchAllCustomProperties()

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertFalse(resources.contains(resource1!))
        XCTAssertFalse(resources.contains(resource2!))
        XCTAssertFalse(resources.contains(resource3!))
        XCTAssert(resources.contains(property1!))
        XCTAssert(resources.contains(property2!))
        XCTAssert(resources.contains(property3!))
    }

    func test_fetchResourcesForSessionId() throws {
        // given a session in storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: TestConstants.processId,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        let resource1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        let resource2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        let resource3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let resource4 = try storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        let resource5 = try storage.addMetadata(
            key: "test5",
            value: "test",
            type: .resource,
            lifespan: .permanent
        )
        let property1 = try storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        let property2 = try storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by session id
        let resources = try storage.fetchResourcesForSessionId(TestConstants.sessionId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssert(resources.contains(resource1!))
        XCTAssertFalse(resources.contains(resource2!))
        XCTAssert(resources.contains(resource3!))
        XCTAssertFalse(resources.contains(resource4!))
        XCTAssert(resources.contains(resource5!))
        XCTAssertFalse(resources.contains(property1!))
        XCTAssertFalse(resources.contains(property2!))
    }

    func test_fetchCustomPropertiesForSessionId() throws {
        // given a session in storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: TestConstants.processId,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        let property1 = try storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        let property2 = try storage.addMetadata(
            key: "test2",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: "test"
        )
        let property3 = try storage.addMetadata(
            key: "test3",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let property4 = try storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        let property5 = try storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .permanent
        )
        let resource1 = try storage.addMetadata(
            key: "test6",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        let resource2 = try storage.addMetadata(
            key: "test7",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by session id
        let resources = try storage.fetchCustomPropertiesForSessionId(TestConstants.sessionId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssert(resources.contains(property1!))
        XCTAssertFalse(resources.contains(property2!))
        XCTAssert(resources.contains(property3!))
        XCTAssertFalse(resources.contains(property4!))
        XCTAssert(resources.contains(property5!))
        XCTAssertFalse(resources.contains(resource1!))
        XCTAssertFalse(resources.contains(resource2!))
    }
}

// swiftlint:enable type_body_length file_length
