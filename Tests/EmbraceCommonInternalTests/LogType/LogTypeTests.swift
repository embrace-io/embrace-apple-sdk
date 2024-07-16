//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommonInternal

final class LogTypeTests: XCTestCase {
    // MARK: - Initialization
    func test_init_setsProperties() {
        let type = LogType(primary: .system, secondary: "example")
        XCTAssertEqual(type.primary, .system)
        XCTAssertEqual(type.secondary, "example")

        XCTAssertEqual(type.rawValue, "sys.example")
    }

    func test_init_without_secondary_setsProperties() {
        let type = LogType(primary: .system)
        XCTAssertEqual(type.primary, .system)
        XCTAssertNil(type.secondary)
    }

    func test_init_system_setsProperties() {
        let type = LogType(system: "example")
        XCTAssertEqual(type.primary, .system)
        XCTAssertEqual(type.secondary, "example")
    }

    // MARK: - RawRepresentable
    func test_rawValue_withoutSecondary_returnsPrimary() {
        let type = LogType(primary: .system)
        XCTAssertEqual(type.rawValue, "sys")
    }

    func test_rawValue_withSecondary_returnsPrimaryAndSecondary_delimitedByDot() {
        let type = LogType(primary: .system, secondary: "example")
        XCTAssertEqual(type.rawValue, "sys.example")
    }

    func test_rawValue_withSecondary_returnsPrimaryAndNestedSecondary_delimitedByDot() {
        let type = LogType(primary: .system, secondary: "example.test")
        XCTAssertEqual(type.rawValue, "sys.example.test")
    }

    func test_init_withRawValue_withoutSecondary_setsProperties() {
        let type = LogType(rawValue: "sys")
        XCTAssertEqual(type?.primary, .system)
        XCTAssertNil(type?.secondary)
    }

    func test_init_withRawValue_withSecondary_setsProperties() {
        let type = LogType(rawValue: "sys.example")
        XCTAssertEqual(type?.primary, .system)
        XCTAssertEqual(type?.secondary, "example")
    }

    func test_init_withRawValue_withNestedSecondary_setsProperties() {
        let type = LogType(rawValue: "sys.example.test")
        XCTAssertEqual(type?.primary, .system)
        XCTAssertEqual(type?.secondary, "example.test")
    }

    func test_init_withRawValue_withInvalidPrimary_returnsNil() {
        let type = LogType(rawValue: "invalid.example")
        XCTAssertNil(type)
    }

    // MARK: - Codable

    func test_encode_withoutSecondary_encodesAsString() throws {
        let type = LogType(primary: .system)
        let encoded = try JSONEncoder().encode(type)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, #""sys""#)
    }

    func test_encode_withSecondary_encodesAsString() throws {
        let type = LogType(primary: .system, secondary: "example")
        let encoded = try JSONEncoder().encode(type)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, #""sys.example""#)
    }

    func test_encode_withNestedSecondary_encodesAsString() throws {
        let type = LogType(primary: .system, secondary: "example.test")
        let encoded = try JSONEncoder().encode(type)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, #""sys.example.test""#)
    }

    func test_decode_withoutSecondary_decodesFromString() throws {
        let encoded = #""sys""#.data(using: .utf8)!
        let type = try JSONDecoder().decode(LogType.self, from: encoded)
        XCTAssertEqual(type.primary, .system)
        XCTAssertNil(type.secondary)
    }

    func test_decode_withSecondary_decodesFromString() throws {
        let encoded = #""sys.example""#.data(using: .utf8)!
        let type = try JSONDecoder().decode(LogType.self, from: encoded)
        XCTAssertEqual(type.primary, .system)
        XCTAssertEqual(type.secondary, "example")
    }

    func test_decode_withNestedSecondary_decodesFromString() throws {
        let encoded = #""sys.example.test""#.data(using: .utf8)!
        let type = try JSONDecoder().decode(LogType.self, from: encoded)
        XCTAssertEqual(type.primary, .system)
        XCTAssertEqual(type.secondary, "example.test")
    }

    func test_decode_withInvalidPrimary_throwsError() throws {
        let encoded = #""invalid.example""#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(LogType.self, from: encoded)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
