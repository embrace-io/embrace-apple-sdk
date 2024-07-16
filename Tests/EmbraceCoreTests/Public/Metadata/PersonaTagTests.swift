//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

final class PersonaTagTests: XCTestCase {

    func test_constantValues() {
        XCTAssertEqual(PersonaTag.maxPersonaTagLength, 32)
        XCTAssertEqual(PersonaTag.metadataValue, "")
    }

    func test_init_setsRawValue() {
        let sut = PersonaTag("example")
        XCTAssertEqual(sut.rawValue, "example")
    }

    func test_init_rawRepresentable_setsRawValue() {
        let sut = PersonaTag(rawValue: "example")
        XCTAssertEqual(sut.rawValue, "example")
    }

    func test_init_stringLiteral_setsRawValue() {
        let sut: PersonaTag = "example"
        XCTAssertEqual(sut.rawValue, "example")
    }

    // MARK: Codable
    func test_encode_encodesAsSingleValue() throws {
        let encoder = JSONEncoder()
        let sut = PersonaTag("example")

        let data = try encoder.encode(sut)
        let encodedString = String(data: data, encoding: .utf8)

        XCTAssertEqual(encodedString, "\"example\"")
    }

    func test_decode_decodesSingleValue() throws {
        let json = "\"example\""
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let sut = try decoder.decode(PersonaTag.self, from: data)

        XCTAssertEqual(sut, PersonaTag("example"))
    }

    // MARK: Validation
    func test_validate_whenValid_doesNotThrow() throws {
        let sut = PersonaTag("example")

        XCTAssertNoThrow(try sut.validate())
    }
    let invalidValue = String(repeating: "a", count: PersonaTag.maxPersonaTagLength + 1)

    func test_validate_whenLengthTooLong_doesThrowCorrectError() throws {
        let invalidTag = String(repeating: "a", count: PersonaTag.maxPersonaTagLength + 1)
        let sut = PersonaTag(invalidTag)

        XCTAssertThrowsError(try sut.validate()) { error in
            XCTAssertEqual(
                error as? MetadataError,
                MetadataError.invalidValue(
                    "The persona tag length can not be greater than \(PersonaTag.maxPersonaTagLength)"
                ))
        }
    }
}
