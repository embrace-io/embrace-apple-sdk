//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import TestSupport
import XCTest
import EmbraceSemantics
@testable import EmbraceCommonInternal
@testable import EmbraceCore
@testable import EmbraceStorageInternal

final class PayloadUtilTests: XCTestCase {
    func test_fetchResources() throws {
        // given
        let mockResources: [EmbraceMetadata] = [
            MockMetadata(
                key: "fake_res",
                value: "fake_value",
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.stringValue
            )
        ]
        let fetcher = MockMetadataFetcher(metadata: mockResources)

        // when
        let fetchedResources = PayloadUtils.fetchResources(from: fetcher, sessionId: .random)

        // then the session payload contains the necessary keys
        XCTAssertEqual(fetchedResources.count, 1)
        XCTAssertEqual(fetchedResources[0].key, mockResources[0].key)
        XCTAssertEqual(fetchedResources[0].value, mockResources[0].value)
        XCTAssertEqual(fetchedResources[0].type, mockResources[0].type)
        XCTAssertEqual(fetchedResources[0].lifespan, mockResources[0].lifespan)
        XCTAssertEqual(fetchedResources[0].lifespanId, mockResources[0].lifespanId)
    }

    func test_fetchCustomProperties() throws {
        // given
        let sessionId = EmbraceIdentifier.random
        let mockResources: [EmbraceMetadata] = [
            MockMetadata(
                key: "fake_res",
                value: "fake_value",
                type: .customProperty,
                lifespan: .session,
                lifespanId: sessionId.stringValue
            )
        ]
        let fetcher = MockMetadataFetcher(metadata: mockResources)

        // when
        let fetchedResources = PayloadUtils.fetchCustomProperties(from: fetcher, sessionId: sessionId)

        // then the session payload contains the necessary keys
        XCTAssertEqual(fetchedResources.count, 1)
        XCTAssertEqual(fetchedResources[0].key, mockResources[0].key)
        XCTAssertEqual(fetchedResources[0].value, mockResources[0].value)
        XCTAssertEqual(fetchedResources[0].type, mockResources[0].type)
        XCTAssertEqual(fetchedResources[0].lifespan, mockResources[0].lifespan)
        XCTAssertEqual(fetchedResources[0].lifespanId, mockResources[0].lifespanId)
    }
}
