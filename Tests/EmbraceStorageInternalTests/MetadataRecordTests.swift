//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

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
        XCTAssertEqual(records.count, storage.options.resourcesLimit)
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
        XCTAssertEqual(records.count, storage.options.customPropertiesLimit)
    }

    func test_addMetadata_resourceLimit_lifespanId() throws {
        // given resources in storage that in total surpass the limit
        // but they correspond to different lifespan ids
        for i in 1...storage.options.resourcesLimit {
            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .userSession,
                lifespanId: i % 2 == 0 ? TestConstants.userSessionId.stringValue : "test"
            )

            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .resource,
                lifespan: .process,
                lifespanId: i % 2 == 0 ? TestConstants.processId.stringValue : "test"
            )
        }

        // when inserting new resources
        let resource1 = storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        let resource2 = storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
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
                lifespan: .userSession,
                lifespanId: i % 2 == 0 ? TestConstants.userSessionId.stringValue : "test"
            )

            storage.addMetadata(
                key: "metadata_\(i)",
                value: "test",
                type: .customProperty,
                lifespan: .process,
                lifespanId: i % 2 == 0 ? TestConstants.processId.stringValue : "test"
            )
        }

        // when inserting new custom properties
        let property1 = storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        let property2 = storage.addMetadata(
            key: "test2",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
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
        // given a stored session part
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(),
            userSessionId: TestConstants.userSessionId
        )

        // and inserted metadata records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test3",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: "test"
        )

        // when cleaning old metadata
        storage.cleanMetadata()

        // then only the correct records should be removed
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 2)
        XCTAssertNotNil(records.first(where: { $0.key == "test1" }))
        XCTAssertNil(records.first(where: { $0.key == "test2" }))
        XCTAssertNotNil(records.first(where: { $0.key == "test3" }))
        XCTAssertNil(records.first(where: { $0.key == "test4" }))
    }

    func test_cleanMetadata_multipleSessions() throws {
        let sessionIdA = EmbraceIdentifier.random
        let sessionIdB = EmbraceIdentifier.random
        let userSessionIdA = EmbraceIdentifier.random
        let userSessionIdB = EmbraceIdentifier.random
        let processIdA = EmbraceIdentifier.random
        let processIdB = EmbraceIdentifier.random

        // given two stored session parts of different user sessions (B shares processId with A)
        storage.addSession(
            id: sessionIdA,
            processId: processIdA,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(),
            userSessionId: userSessionIdA
        )
        storage.addSession(
            id: sessionIdB,
            processId: processIdA,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(),
            userSessionId: userSessionIdB
        )

        // user-session-lifespan metadata for both user sessions (should be kept)
        storage.addMetadata(key: "sesA", value: "v", type: .resource, lifespan: .userSession, lifespanId: userSessionIdA.stringValue)
        storage.addMetadata(key: "sesB", value: "v", type: .resource, lifespan: .userSession, lifespanId: userSessionIdB.stringValue)

        // user-session-lifespan metadata for a non-existent user session (should be deleted)
        storage.addMetadata(key: "sesOrphan", value: "v", type: .resource, lifespan: .userSession, lifespanId: "nonexistent")

        // user-session-lifespan metadata keyed by a session part id, as written before the lifespan
        // was scoped to user sessions (should be deleted)
        storage.addMetadata(key: "sesLegacy", value: "v", type: .resource, lifespan: .userSession, lifespanId: sessionIdA.stringValue)

        // process-lifespan metadata for the shared process (should be kept)
        storage.addMetadata(key: "procA", value: "v", type: .resource, lifespan: .process, lifespanId: processIdA.stringValue)

        // process-lifespan metadata for a non-existent process (should be deleted)
        storage.addMetadata(key: "procOrphan", value: "v", type: .resource, lifespan: .process, lifespanId: processIdB.stringValue)

        // permanent metadata (should always be kept)
        storage.addMetadata(key: "perm", value: "v", type: .resource, lifespan: .permanent)

        // when cleaning metadata
        storage.cleanMetadata()

        // then metadata for stored sessions and their processes is preserved
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertNotNil(records.first(where: { $0.key == "sesA" }))
        XCTAssertNotNil(records.first(where: { $0.key == "sesB" }))
        XCTAssertNotNil(records.first(where: { $0.key == "procA" }))
        XCTAssertNotNil(records.first(where: { $0.key == "perm" }))

        // and orphaned metadata is deleted, including the part-keyed one
        XCTAssertNil(records.first(where: { $0.key == "sesOrphan" }))
        XCTAssertNil(records.first(where: { $0.key == "sesLegacy" }))
        XCTAssertNil(records.first(where: { $0.key == "procOrphan" }))

        XCTAssertEqual(records.count, 4)
    }

    func test_cleanMetadata_noSessions() throws {
        // given no stored sessions but existing metadata
        storage.addMetadata(key: "ses", value: "v", type: .resource, lifespan: .userSession, lifespanId: "any")
        storage.addMetadata(key: "proc", value: "v", type: .resource, lifespan: .process, lifespanId: "any")
        storage.addMetadata(key: "perm", value: "v", type: .resource, lifespan: .permanent)

        // when cleaning metadata
        storage.cleanMetadata()

        // then all user session and process metadata is deleted, permanent is kept
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records.first(where: { $0.key == "perm" }))
    }

    func test_cleanMetadata_keepsMetadataOfActiveUserSession_whenNoSessionPartRemains() throws {
        let activeUserSessionId = EmbraceIdentifier.random

        // given metadata of the active user session, but no stored session part referencing it
        // (its parts were already uploaded and deleted)
        storage.addMetadata(
            key: "active", value: "v", type: .customProperty,
            lifespan: .userSession, lifespanId: activeUserSessionId.stringValue
        )
        storage.addMetadata(
            key: "other", value: "v", type: .customProperty,
            lifespan: .userSession, lifespanId: EmbraceIdentifier.random.stringValue
        )

        // when cleaning metadata protecting the active user session
        storage.cleanMetadata(activeUserSessionId: activeUserSessionId)

        // then its metadata survives and the rest is deleted
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records.first(where: { $0.key == "active" }))
    }

    func test_cleanMetadata_keepsUserSessionMetadata_whenOnlySomePartsRemain() throws {
        let userSessionId = EmbraceIdentifier.random
        let processId = EmbraceIdentifier.random
        let partId1 = EmbraceIdentifier.random
        let partId2 = EmbraceIdentifier.random

        // given two session parts of the same user session
        for partId in [partId1, partId2] {
            storage.addSession(
                id: partId,
                processId: processId,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(),
                userSessionId: userSessionId
            )
        }

        storage.addMetadata(
            key: "prop", value: "v", type: .customProperty,
            lifespan: .userSession, lifespanId: userSessionId.stringValue
        )

        // when one of the parts is uploaded and deleted
        storage.deleteSession(id: partId1)
        storage.cleanMetadata()

        // then the metadata is kept, since the user session still has a stored part
        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records.first(where: { $0.key == "prop" }))
    }

    func test_cleanMetadata_preservesAllMetadataTypes() throws {
        let sessionId = EmbraceIdentifier.random
        let userSessionId = EmbraceIdentifier.random
        let processId = EmbraceIdentifier.random

        storage.addSession(
            id: sessionId,
            processId: processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(),
            userSessionId: userSessionId
        )

        // metadata of various types tied to the stored session part's user session
        storage.addMetadata(key: "res", value: "v", type: .resource, lifespan: .userSession, lifespanId: userSessionId.stringValue)
        storage.addMetadata(key: "cp", value: "v", type: .customProperty, lifespan: .userSession, lifespanId: userSessionId.stringValue)
        storage.addMetadata(key: "pt", value: "v", type: .personaTag, lifespan: .process, lifespanId: processId.stringValue)
        storage.addMetadata(key: "rr", value: "v", type: .requiredResource, lifespan: .process, lifespanId: processId.stringValue)

        // orphaned metadata of various types
        storage.addMetadata(key: "res_orphan", value: "v", type: .resource, lifespan: .userSession, lifespanId: "gone")
        storage.addMetadata(key: "cp_orphan", value: "v", type: .customProperty, lifespan: .process, lifespanId: "gone")
        storage.addMetadata(key: "pt_orphan", value: "v", type: .personaTag, lifespan: .userSession, lifespanId: "gone")

        storage.cleanMetadata()

        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertNotNil(records.first(where: { $0.key == "res" }))
        XCTAssertNotNil(records.first(where: { $0.key == "cp" }))
        XCTAssertNotNil(records.first(where: { $0.key == "pt" }))
        XCTAssertNotNil(records.first(where: { $0.key == "rr" }))
        XCTAssertNil(records.first(where: { $0.key == "res_orphan" }))
        XCTAssertNil(records.first(where: { $0.key == "cp_orphan" }))
        XCTAssertNil(records.first(where: { $0.key == "pt_orphan" }))
        XCTAssertEqual(records.count, 4)
    }

    func test_cleanMetadata_multipleSessionsDifferentProcesses() throws {
        let sessionIdA = EmbraceIdentifier.random
        let sessionIdB = EmbraceIdentifier.random
        let processIdA = EmbraceIdentifier.random
        let processIdB = EmbraceIdentifier.random

        // two sessions with different process ids
        storage.addSession(
            id: sessionIdA,
            processId: processIdA,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        storage.addSession(
            id: sessionIdB,
            processId: processIdB,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // process metadata for both processes (should be kept)
        storage.addMetadata(key: "procA", value: "v", type: .resource, lifespan: .process, lifespanId: processIdA.stringValue)
        storage.addMetadata(key: "procB", value: "v", type: .resource, lifespan: .process, lifespanId: processIdB.stringValue)

        // process metadata for a third, non-existent process (should be deleted)
        storage.addMetadata(key: "procC", value: "v", type: .resource, lifespan: .process, lifespanId: "unknown")

        storage.cleanMetadata()

        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertNotNil(records.first(where: { $0.key == "procA" }))
        XCTAssertNotNil(records.first(where: { $0.key == "procB" }))
        XCTAssertNil(records.first(where: { $0.key == "procC" }))
        XCTAssertEqual(records.count, 2)
    }

    func test_cleanMetadata_sessionDeletedThenClean() throws {
        let sessionId = EmbraceIdentifier.random
        let userSessionId = EmbraceIdentifier.random
        let processId = EmbraceIdentifier.random

        // add a session part and metadata for its user session
        storage.addSession(
            id: sessionId,
            processId: processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(),
            userSessionId: userSessionId
        )
        storage.addMetadata(key: "ses", value: "v", type: .resource, lifespan: .userSession, lifespanId: userSessionId.stringValue)
        storage.addMetadata(key: "proc", value: "v", type: .resource, lifespan: .process, lifespanId: processId.stringValue)

        // delete the session (simulating it was uploaded)
        storage.deleteSession(id: sessionId)

        // when cleaning, the metadata should now be orphaned
        storage.cleanMetadata()

        let records: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(records.count, 0)
    }

    func test_removeMetadata() throws {
        // given inserted record
        storage.addMetadata(
            key: "test",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: "test"
        )

        // when removing it
        storage.removeMetadata(key: "test", type: .resource, lifespan: .userSession, lifespanId: "test")

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
            lifespan: .userSession,
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
            lifespan: .userSession,
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
        storage.removeAllMetadata(type: .resource, lifespans: [.userSession, .process])

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
            lifespan: .userSession,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test5",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: "test"
        )
        storage.addMetadata(
            key: "test6",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
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
            lifespanId: TestConstants.processId.stringValue
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .userSession,
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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )

        // when fetching all resources by session id and process id
        let resources = storage.fetchResources(userSessionId: TestConstants.userSessionId, processId: TestConstants.processId)

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

    func test_fetchResourcesForSessionPart() throws {
        // given a session part in storage, belonging to a user session with a different id
        let part = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: TestConstants.processId,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(),
                userSessionId: TestConstants.userSessionId
            )
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .resource,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .userSession,
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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )

        // when fetching all resources for the session part
        let resources = storage.fetchResources(for: part)

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
            lifespanId: TestConstants.processId.stringValue
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .resource,
            lifespan: .userSession,
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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
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
            lifespanId: TestConstants.processId.stringValue
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )

        // when fetching all resources by session id and process id
        let resources = storage.fetchCustomProperties(userSessionId: TestConstants.userSessionId, processId: TestConstants.processId)

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

    func test_fetchCustomPropertiesForSessionPart() throws {
        // given a session part in storage, belonging to a user session with a different id
        let part = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: TestConstants.processId,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(),
                userSessionId: TestConstants.userSessionId
            )
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test4",
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )

        // when fetching all custom properties for the session part
        let resources = storage.fetchCustomProperties(for: part)

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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
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
            lifespan: .userSession,
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .personaTag,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
        )

        // when fetching all persona tags by session id and process id
        let resources = storage.fetchPersonaTags(userSessionId: TestConstants.userSessionId, processId: TestConstants.processId)

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

    func test_fetchPersonaTagsForSessionPart() throws {
        // given a session part in storage, belonging to a user session with a different id
        let part = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: TestConstants.processId,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(),
                userSessionId: TestConstants.userSessionId
            )
        )

        // given inserted records
        storage.addMetadata(
            key: "test1",
            value: "test",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
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
            lifespan: .userSession,
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .personaTag,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
        )

        // when fetching all persona tags for the session part
        let resources = storage.fetchPersonaTags(for: part)

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
            lifespanId: TestConstants.processId.stringValue
        )
        storage.addMetadata(
            key: "test2",
            value: "test",
            type: .resource,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
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
            lifespan: .userSession,
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
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test7",
            value: "test",
            type: .personaTag,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
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
