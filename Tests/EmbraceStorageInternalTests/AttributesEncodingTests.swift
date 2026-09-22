//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import XCTest

@testable import EmbraceStorageInternal

class AttributesEncodingTests: XCTestCase {

    func test_encode() {
        let dict: EmbraceAttributes = [
            "key": "value",
            "key,": "value,",
            "key%2C": "value%2C"
        ]
        let result = dict.keyValueEncoded()

        XCTAssert(result.contains("key,"))
        XCTAssert(result.contains("value"))
        XCTAssert(result.contains("key%2C,"))
        XCTAssert(result.contains("value%2C"))
        XCTAssert(result.contains("key%252C,"))
        XCTAssert(result.contains("value%252C"))
    }

    func test_decode() {
        let string = "key,value,key%2C,value%2C,key%252C,value%252C"
        let result = Dictionary.keyValueDecode(string)

        XCTAssertEqual(
            result,
            [
                "key": "value",
                "key,": "value,",
                "key%2C": "value%2C"
            ])
    }
}
