//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

class EmbraceIdentifierTests: XCTestCase {

    func test_init_uuid() {
        // given an identifier from an uuid
        let uuid = UUID()
        let id = EmbraceIdentifier(value: uuid)

        // then the identifier is created correctly
        XCTAssertEqual(id.stringValue, uuid.withoutHyphen)
    }

    func test_init_string() {
        // given an identifier from a string
        let string = "test"
        let id = EmbraceIdentifier(stringValue: string)

        // then the identifier is created correctly
        XCTAssertEqual(id.stringValue, string)
    }
}
