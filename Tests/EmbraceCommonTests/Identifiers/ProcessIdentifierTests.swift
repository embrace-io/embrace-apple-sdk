//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCommon

final class ProcessIdentifierTests: XCTestCase {

    func test_init_value() throws {
        let value: UInt32 = 123
        let processIdentifier = ProcessIdentifier(value: value)
        XCTAssertEqual(processIdentifier.value, value)
    }

    func test_init_hex_withEmptyString_returnsNil() throws {
        XCTAssertNil(ProcessIdentifier(hex: ""))
    }

    func test_init_hex_withInvalidString_returnsNil() throws {
        XCTAssertNil(ProcessIdentifier(hex: "Hello World"))
    }

    func test_init_hex_withShortString_returnsNonNil() throws {
        XCTAssertEqual(ProcessIdentifier(hex: "0")?.value, 0)
        XCTAssertEqual(ProcessIdentifier(hex: "001")?.value, 1)
        XCTAssertEqual(ProcessIdentifier(hex: "F")?.value, 15)
    }

    func test_init_hex_withLongString_returnsNonNil() throws {
        XCTAssertNotNil(ProcessIdentifier(hex: "0AA43212"))
        XCTAssertNotNil(ProcessIdentifier(hex: "001423AB"))
        XCTAssertNotNil(ProcessIdentifier(hex: "12345678"))

        // returns nil if overflows UInt32.max
        XCTAssertNotNil(ProcessIdentifier(hex: "FFFFFFFF"))
        XCTAssertNil(ProcessIdentifier(hex: "1FFFFFFFF"))
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

    func test_decode_withValidString_returnsCorrectValue() throws {
        let data = try JSONEncoder().encode("01")

        let identifier = try JSONDecoder().decode(ProcessIdentifier.self, from: data)
        XCTAssertEqual(identifier.value, 1)
    }

    func test_encode_encodesValueInHex() throws {
        let processIdentifier = ProcessIdentifier(value: 1)
        let data = try JSONEncoder().encode(processIdentifier)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"00000001\"")
    }

}
