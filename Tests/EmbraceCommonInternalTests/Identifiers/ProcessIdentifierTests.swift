//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommonInternal

final class ProcessIdentifierTests: XCTestCase {

    func test_init_value() throws {
        let value: UUID = UUID()
        let processIdentifier = ProcessIdentifier(uuid: value)
        XCTAssertEqual(processIdentifier.value, value.uuidString)
    }

    func test_random_returnsNewValue() throws {
        XCTAssertNotEqual(ProcessIdentifier.random, ProcessIdentifier.random)
    }

    func test_encodeAndDecode_returnsSameValue() throws {
        let processIdentifier = ProcessIdentifier.random
        let data = try JSONEncoder().encode(processIdentifier)
        let decoded = try JSONDecoder().decode(ProcessIdentifier.self, from: data)
        XCTAssertEqual(processIdentifier, decoded)
    }

    func test_decode_withEmptyString_throwsError() throws {
        let data = try JSONEncoder().encode("")
        XCTAssertThrowsError(
            try JSONDecoder().decode(ProcessIdentifier.self, from: data)
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func test_decode_withInvalidString_throwsError() throws {
        let data = try JSONEncoder().encode("QRS")
        XCTAssertThrowsError(
            try JSONDecoder().decode(ProcessIdentifier.self, from: data)
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
