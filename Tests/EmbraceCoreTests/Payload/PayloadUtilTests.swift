//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceStorageInternal
@testable import EmbraceCommonInternal
import OpenTelemetryApi

final class PayloadUtilTests: XCTestCase {
    func test_fetchResources() throws {
        // given
        let mockResources: [MetadataRecord] = [
            .init(
                key: "fake_res",
                value: .string("fake_value"),
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.hex
            )
        ]
        let fetcher = MockMetadataFetcher(metadata: mockResources)

        // when
        let fetchedResources = PayloadUtils.fetchResources(from: fetcher, sessionId: .random)

        // then the session payload contains the necessary keys
        XCTAssertEqual(mockResources, fetchedResources)
    }

    func test_convertSpanAttributes() throws {
        // given some span attributes
        let attributes: [String: AttributeValue] = [
            "bool": .bool(true),
            "boolArray": .boolArray([true, false]),
            "double": .double(123.456),
            "doubleArray": .doubleArray([123.456, 987.654]),
            "int": .int(123456),
            "intArray": .intArray([123456, 987654]),
            "string": .string("test"),
            "stringArray": .stringArray(["test1", "test2"])
        ]

        // when converting them
        let converted = PayloadUtils.convertSpanAttributes(attributes)

        // then values are converted correctly
        let boolAttribute = converted.first { $0.key == "bool" }
        XCTAssertEqual(boolAttribute!.value, "true")

        let doubleAttribute = converted.first { $0.key == "double" }
        XCTAssertEqual(doubleAttribute!.value, "123.456")

        let intAttribute = converted.first { $0.key == "int" }
        XCTAssertEqual(intAttribute!.value, "123456")

        let stringAttribute = converted.first { $0.key == "string" }
        XCTAssertEqual(stringAttribute!.value, "test")

        // and array values are discarded
        XCTAssertEqual(converted.count, 4)
    }

    func test_fetchCustomProperties() throws {
        // given
        let sessionId = SessionIdentifier.random
        let mockResources: [MetadataRecord] = [
            .init(
                key: "fake_res",
                value: .string("fake_value"),
                type: .customProperty,
                lifespan: .session,
                lifespanId: sessionId.toString
            )
        ]
        let fetcher = MockMetadataFetcher(metadata: mockResources)

        // when
        let fetchedResources = PayloadUtils.fetchCustomProperties(from: fetcher, sessionId: sessionId)

        // then the session payload contains the necessary keys
        XCTAssertEqual(mockResources, fetchedResources)
    }
}
