//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceStorage
@testable import EmbraceCommon
import OpenTelemetryApi

// swiftlint:disable force_cast

final class PayloadUtilTests: XCTestCase {
    func test_fetchResources() throws {
        // given
        let mockResources: [MetadataRecord] = [
            .init(
                key: "fake_res",
                value: .string("fake_value"),
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.random.hex
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
        XCTAssertEqual(converted["bool"] as! Bool, true)
        XCTAssertEqual(converted["double"] as! Double, 123.456)
        XCTAssertEqual(converted["int"] as! Int, 123456)
        XCTAssertEqual(converted["string"] as! String, "test")

        // and array values are discarded
        XCTAssertNil(converted["boolArray"])
        XCTAssertNil(converted["doubleArray"])
        XCTAssertNil(converted["intArray"])
        XCTAssertNil(converted["stringArray"])
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

// swiftlint:enable force_cast
