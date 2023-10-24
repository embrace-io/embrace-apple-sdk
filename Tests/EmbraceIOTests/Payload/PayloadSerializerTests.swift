//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import UIKit
@testable import EmbraceIO
@testable import EmbraceStorage

final class PayloadSerializerTests: XCTestCase {

    func testSerialization() {
        // Given
        let json = TestCodable()
        let serializer = PayloadSerializer()

        // When
        let result = serializer.serializeAndGZipJson(json)

        // Then
        if let data = result.data {
            if let resultDictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                XCTAssertEqual(resultDictionary["foo"] as? String, "something")
            } else {
                XCTFail("\(#function): Failed Serializing Dictionary")
            }
        } else {
            XCTFail("\(#function): Got Empty Data")
        }
    }

    func testSerialization_Error() {
        // Given
        let serializer = PayloadSerializer()

        // When
        let result = serializer.serializeAndGZipJson(TestFailCodable())

        // Then
        XCTAssertNil(result.data)
        XCTAssertEqual(result.error, .serializationFailed)
    }

    class TestCodable: Codable {
        var foo: String

        init() {
            foo = "something"
        }
    }

    class TestFailCodable: Codable {
        var foo: Double

        init() {
            foo = Double.infinity
        }
    }
}
