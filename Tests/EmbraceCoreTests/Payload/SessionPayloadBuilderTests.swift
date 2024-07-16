//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceStorageInternal
import EmbraceCommonInternal
import TestSupport

final class SessionPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: SessionRecord!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        sessionRecord = SessionRecord(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60)
        )
    }

    override func tearDownWithError() throws {
        try storage.dbQueue.write { db in
            try SessionRecord.deleteAll(db)
            try MetadataRecord.deleteAll(db)
        }

        sessionRecord = nil
        try storage.teardown()
    }

    func test_counterMissing() throws {
        // given no existing counter in storage
        var resource = try storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )
        XCTAssertNil(resource)

        // when building a session payload
        _ = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then a resource is created with the correct value
        resource = try storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )

        XCTAssertEqual(resource!.value, .string("1"))
    }

    func test_existingCounter() throws {
        // given existing counter in storage
        try storage.addMetadata(
            key: SessionPayloadBuilder.resourceName,
            value: "10",
            type: .requiredResource,
            lifespan: .permanent
        )

        var resource = try storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )
        XCTAssertNotNil(resource)

        // when building a session payload
        _ = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the counter is updated correctly
        resource = try storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )

        XCTAssertEqual(resource!.value, .string("11"))
    }
}
