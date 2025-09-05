//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class SessionPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: MockSession!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        sessionRecord = MockSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60)
        )
    }

    override func tearDownWithError() throws {
        sessionRecord = nil
        storage.coreData.destroy()
    }

    func test_counterMissing() throws {
        // given no existing counter in storage
        var resource = storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )
        XCTAssertNil(resource)

        // when building a session payload
        _ = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then a resource is created with the correct value
        resource = storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )

        XCTAssertEqual(resource!.value, "1")
    }

    func test_existingCounter() throws {
        // given existing counter in storage
        storage.addMetadata(
            key: SessionPayloadBuilder.resourceName,
            value: "10",
            type: .requiredResource,
            lifespan: .permanent
        )

        var resource = storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )
        XCTAssertNotNil(resource)

        // when building a session payload
        _ = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the counter is updated correctly
        resource = storage.fetchMetadata(
            key: SessionPayloadBuilder.resourceName,
            type: .requiredResource,
            lifespan: .permanent
        )

        XCTAssertEqual(resource!.value, "11")
    }
}
