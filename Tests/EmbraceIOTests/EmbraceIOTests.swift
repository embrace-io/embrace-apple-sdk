//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceIO

class EmbraceIOTests: XCTestCase {

    func test_newAttribtues() {

        let atts: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValue] = [
            "key1": true,
            "key2": 12,
            "key3": 12.123,
            "key4": "string"
        ]

        let data = try! JSONEncoder().encode(atts)
        let decoded = try! JSONDecoder().decode([EmbraceIO.AttributeKey: EmbraceIO.AttributeValue].self, from: data)
        XCTAssertEqual(atts, decoded)
    }

    func test_internals() {

        let atts: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValue] = [
            "key1": true,
            "key2": 12,
            "key3": 12.123,
            "key4": "string"
        ]

        let internalsValue = [
            "key1": "true",
            "key2": "12",
            "key3": "12.123",
            "key4": "string"
        ]

        let internals = atts.asInternalAttributes()
        XCTAssertEqual(internals, internalsValue)
    }
}
