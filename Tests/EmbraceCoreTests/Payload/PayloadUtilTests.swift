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

    @available(*, deprecated)
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
            /*
             "bool": .bool(true),
             "boolArray": .array(AttributeArray(values: [.bool(true), .bool(true)])),
             "double": .double(123.456),
             "doubleArray": .array(AttributeArray(values: [.double(123.456), .double(987.654)])),
             "int": .int(123456),
             "intArray": .array(AttributeArray(values: [.int(123456), .int(987654)])),
             "string": .string("test"),
             "stringArray": .array(AttributeArray(values: [.string("test1"), .string("test2")]))
             */
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
