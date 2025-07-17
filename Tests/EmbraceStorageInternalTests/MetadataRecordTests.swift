//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommonInternal
@testable import EmbraceStorageInternal

class MetadataRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

    func test_addMetadata() throws {
        // given inserted metadata
        let metadata = storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)
        XCTAssertNotNil(metadata)

        // then the record should exist in storage
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].key, "test")
        XCTAssertEqual(records[0].typeRaw, "resource")
        XCTAssertEqual(records[0].lifespanRaw, "permanent")
    }

    func test_addMetadata_resourceLimit() throws {
        // given limit reached on resources
        for i in 1...storage.options.resourcesLimit {
            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .permanent
            )
        }

        // when inserting a new resource
        let resource = storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)

        // then it should not be inserted
        XCTAssertNil(resource)

        // then the record count should be the limit
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count,  storage.options.resourcesLimit)
    }

    func test_addMetadata_customPropertiesLimit() throws {
        // given limit reached on custom properties
        for i in 1...storage.options.customPropertiesLimit {
            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .permanent
            )
        }

        // when inserting a new custom property
        let resource = storage.addMetadata(key: "test", value: "test", type: .customProperty, lifespan: .permanent)

        // then it should not be inserted
        XCTAssertNil(resource)

        // then the record count should be the limit
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count,  storage.options.customPropertiesLimit)
    }

    func test_addMetadata_resourceLimit_lifespanId() throws {
        // given resources in storage that in total surpass the limit
        // but they correspond to different lifespan ids
        for i in 1...storage.options.resourcesLimit {
            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .session,
                lifespanId: i % 2 == 0 ? TestConstants.sessionId.toString : "test"
            )

            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .process,
                lifespanId: i % 2 == 0 ? TestConstants.processId.hex : "test"
            )
        }

        // when inserting new resources
        let resource1 = storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let resource2 = storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // then they should be inserted
        XCTAssertNotNil(resource1)
        XCTAssertNotNil(resource2)

        // then the record count should be the limit
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, storage.options.resourcesLimit * 2 + 2)
        XCTAssertNotNil(records.first(where: { $0.key == "test1" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test2" }))
    }

    func test_addMetadata_customPropertiesLimit_lifespanId() throws {
        // given custom properties in storage that in total surpass the limit
        // but they correspond to different lifespan ids
        for i in 1...storage.options.customPropertiesLimit {
            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .session,
                lifespanId: i % 2 == 0 ? TestConstants.sessionId.toString : "test"
            )

            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .process,
                lifespanId: i % 2 == 0 ? TestConstants.processId.hex : "test"
            )
        }

        // when inserting new custom properties
        let property1 = storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        let property2 = storage.addMetadata(
            key: "test2",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // then they should be inserted
        XCTAssertNotNil(property1)
        XCTAssertNotNil(property2)

        // then the record count should be the limit
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, storage.options.customPropertiesLimit * 2 + 2)
        XCTAssertNotNil(records.first(where: { $0.key == "test1" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test2" }))
    }

    func test_addMetadata_requiredResource() throws {
        // given limit reached on resources and custom properties
        for i in 0...storage.options.resourcesLimit {
            storage.addMetadata(key: "resource_\(i)", value: "test", type: .resource, lifespan: .permanent)
            storage.addMetadata(key: "property_\(i)", value: "test", type: .customProperty, lifespan: .permanent)
        }

        // when inserting a new required resource
        let requiredResource = storage.addMetadata(
            key: "test",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )

        // then it should be inserted despite the limits
        XCTAssertNotNil(requiredResource)

        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, storage.options.resourcesLimit + storage.options.customPropertiesLimit + 1)
        XCTAssertNotNil(records.first(where: { $0.key == "test" }))
    }

    func test_updateMetadata() throws {
        // given inserted record
        storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)

        // when updating its value
        storage.updateMetadata(key: "test", value: "value", type: .resource, lifespan: .permanent, lifespanId: "")

        // then record should exist in storage with the correct value
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].value, "value")
    }

    func test_cleanMetadata() throws {
        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when cleaning old metadata
        storage.cleanMetadata(
            currentSessionId: TestConstants.sessionId.toString,
            currentProcessId: TestConstants.processId.hex
        )

        // then only the correct records should be removed
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 2)
        XCTAssertNotNil(records.first(where: { $0.key == "test1" }))
        XCTAssertNil(records.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test3" }))
        XCTAssertNil(records.first(where: { $0.key == "test4" }))
    }

    func test_removeMetadata() throws {
        // given inserted record
        storage.addMetadata(
            key: "test",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )

        // when removing it
        storage.removeMetadata(key: "test", type: .resource, lifespan: .session, lifespanId: "test")

        // then record should not exist in storage
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 0)
    }

    func test_removeAllMetadata_severalLifespans() throws {
        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when removing all by type and lifespans
        storage.removeAllMetadata(type: .resource, lifespans: [.session, .process])

        // then only the correct records should be removed
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 2)
        XCTAssertNil(records.first(where: { $0.key == "test1" }))
        XCTAssertNil(records.first(where: { $0.key == "test2" }))
        XCTAssertNil(records.first(where: { $0.key == "test3" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test5" }))
    }

    func test_removeAllMetadata_severalKeys() throws {
        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when removing all by keys and lifespan
        storage.removeAllMetadata(keys: ["test1", "test3", "test4"], lifespan: .process)

        // then only the correct records should be removed
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 2)
        XCTAssertNil(records.first(where: { $0.key == "test1" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test2" }))
        XCTAssertNil(records.first(where: { $0.key == "test3" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test4" }))
    }

    func test_fetchMetadata() throws {
        // given inserted record
        storage.addMetadata(key: "test", value: "test", type: .resource, lifespan: .permanent)

        // when fetching it
        let record = storage.fetchMetadata(key: "test", type: .resource, lifespan: .permanent)

        // then its correctly fetched
        XCTAssertNotNil(record)
    }

    func test_fetchRequiredPermanentResource() throws {
        // given inserted permanent required resource
        storage.addMetadata(key: "test", value: "test", type: .requiredResource, lifespan: .permanent)

        // when fetching it
        let record = storage.fetchRequiredPermanentResource(key: "test")

        // then its correctly fetched
        XCTAssertNotNil(record)
    }

    func test_fetchAllResources() throws {
        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )

        // when fetching all resources
        let resources = storage.fetchAllResources()

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNotNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
    }

    func test_fetchResources() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .resource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by session id and process id
        let resources = storage.fetchResources(sessionId: TestConstants.sessionId.toString, processId: TestConstants.processId.hex)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNotNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchResourcesForSessionId() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .resource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by session id
        let resources = storage.fetchResourcesForSessionId(TestConstants.sessionId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNotNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchResourcesForProcessId() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .resource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by process id
        let resources = storage.fetchResourcesForProcessId(TestConstants.processId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 2)
        XCTAssertNotNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchCustomProperties() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by session id and process id
        let resources = storage.fetchCustomProperties(sessionId: TestConstants.sessionId.toString, processId: TestConstants.processId.hex)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNotNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchCustomPropertiesForSessionId() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )

        // when fetching all resources by session id
        let resources = storage.fetchCustomPropertiesForSessionId(TestConstants.sessionId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNotNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchPersonaTags() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .personaTag,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .personaTag,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .personaTag,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // when fetching all persona tags by session id and process id
        let resources = storage.fetchPersonaTags(sessionId: TestConstants.sessionId.toString, processId: TestConstants.processId.hex)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchPersonaTagsForSessionId() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .personaTag,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .personaTag,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .personaTag,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // when fetching all persona tags by session
        let resources = storage.fetchPersonaTagsForSessionId(TestConstants.sessionId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 3)
        XCTAssertNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test7" }))
    }

    func test_fetchPersonaTagsForProcessId() throws {
        // given a session in storage
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .personaTag,
            lifespan: .session,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .personaTag,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .personaTag,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // when fetching all persona tags by session
        let resources = storage.fetchPersonaTagsForProcessId(TestConstants.processId)

        // then the correct records are fetched
        XCTAssertEqual(resources.count, 2)
        XCTAssertNil(resources.first(where: { $0.key == "test1" }))
        XCTAssertNil(resources.first(where: { $0.key == "test2" }))
        XCTAssertNil(resources.first(where: { $0.key == "test3" }))
        XCTAssertNil(resources.first(where: { $0.key == "test4" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test5" }))
        XCTAssertNil(resources.first(where: { $0.key == "test6" }))
        XCTAssertNotNil(resources.first(where: { $0.key == "test7" }))
    }
}
