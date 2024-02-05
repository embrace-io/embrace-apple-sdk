//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommon

final class SpanTypeTests: XCTestCase {

    // MARK: - Initialization
    func test_init_setsProperties() {
        let type = SpanType(primary: .performance, secondary: "example")
        XCTAssertEqual(type.primary, .performance)
        XCTAssertEqual(type.secondary, "example")

        XCTAssertEqual(type.rawValue, "performance.example")
    }

    func test_init_without_secondary_setsProperties() {
        let type = SpanType(primary: .performance)
        XCTAssertEqual(type.primary, .performance)
        XCTAssertNil(type.secondary)
    }

    func test_init_performance_setsProperties() {
        let type = SpanType(performance: "example")
        XCTAssertEqual(type.primary, .performance)
        XCTAssertEqual(type.secondary, "example")
    }

    func test_init_ux_setsProperties() {
        let type = SpanType(ux: "example")
        XCTAssertEqual(type.primary, .ux)
        XCTAssertEqual(type.secondary, "example")
    }

    func test_init_system_setsProperties() {
        let type = SpanType(system: "example")
        XCTAssertEqual(type.primary, .system)
        XCTAssertEqual(type.secondary, "example")
    }

    // MARK: - RawRepresentable
    func test_rawValue_withoutSecondary_returnsPrimary() {
        let type = SpanType(primary: .performance)
        XCTAssertEqual(type.rawValue, "performance")
    }

    func test_rawValue_withSecondary_returnsPrimaryAndSecondary_delimitedByDot() {
        let type = SpanType(primary: .performance, secondary: "example")
        XCTAssertEqual(type.rawValue, "performance.example")
    }

    func test_rawValue_withSecondary_returnsPrimaryAndNestedSecondary_delimitedByDot() {
        let type = SpanType(primary: .performance, secondary: "example.test")
        XCTAssertEqual(type.rawValue, "performance.example.test")
    }

    func test_init_withRawValue_withoutSecondary_setsProperties() {
        let type = SpanType(rawValue: "performance")
        XCTAssertEqual(type?.primary, .performance)
        XCTAssertNil(type?.secondary)
    }

    func test_init_withRawValue_withSecondary_setsProperties() {
        let type = SpanType(rawValue: "performance.example")
        XCTAssertEqual(type?.primary, .performance)
        XCTAssertEqual(type?.secondary, "example")
    }

    func test_init_withRawValue_withNestedSecondary_setsProperties() {
        let type = SpanType(rawValue: "performance.example.test")
        XCTAssertEqual(type?.primary, .performance)
        XCTAssertEqual(type?.secondary, "example.test")
    }

    func test_init_withRawValue_withInvalidPrimary_returnsNil() {
        let type = SpanType(rawValue: "invalid.example")
        XCTAssertNil(type)
    }

    // MARK: CustomStringConvertible
    func test_description_withoutSecondary_returnsPrimary() {
        let type = SpanType(primary: .ux)
        XCTAssertEqual(type.description, "ux")
    }

    func test_description_withSecondary_returnsPrimaryAndSecondary_delimitedByDot() {
        let type = SpanType(primary: .ux, secondary: "example")
        XCTAssertEqual(type.description, "ux.example")
    }

    func test_description_withSecondary_returnsPrimaryAndNestedSecondary_delimitedByDot() {
        let type = SpanType(primary: .ux, secondary: "example.test")
        XCTAssertEqual(type.description, "ux.example.test")
    }

    // MARK: - Codable

    func test_encode_withoutSecondary_encodesAsString() throws {
        let type = SpanType(primary: .performance)
        let encoded = try JSONEncoder().encode(type)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, #""performance""#)
    }

    func test_encode_withSecondary_encodesAsString() throws {
        let type = SpanType(primary: .performance, secondary: "example")
        let encoded = try JSONEncoder().encode(type)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, #""performance.example""#)
    }

    func test_encode_withNestedSecondary_encodesAsString() throws {
        let type = SpanType(primary: .performance, secondary: "example.test")
        let encoded = try JSONEncoder().encode(type)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, #""performance.example.test""#)
    }

    func test_decode_withoutSecondary_decodesFromString() throws {
        let encoded = #""performance""#.data(using: .utf8)!
        let type = try JSONDecoder().decode(SpanType.self, from: encoded)
        XCTAssertEqual(type.primary, .performance)
        XCTAssertNil(type.secondary)
    }

    func test_decode_withSecondary_decodesFromString() throws {
        let encoded = #""performance.example""#.data(using: .utf8)!
        let type = try JSONDecoder().decode(SpanType.self, from: encoded)
        XCTAssertEqual(type.primary, .performance)
        XCTAssertEqual(type.secondary, "example")
    }

    func test_decode_withNestedSecondary_decodesFromString() throws {
        let encoded = #""performance.example.test""#.data(using: .utf8)!
        let type = try JSONDecoder().decode(SpanType.self, from: encoded)
        XCTAssertEqual(type.primary, .performance)
        XCTAssertEqual(type.secondary, "example.test")
    }

    func test_decode_withInvalidPrimary_throwsError() throws {
        let encoded = #""invalid.example""#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SpanType.self, from: encoded)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

}
