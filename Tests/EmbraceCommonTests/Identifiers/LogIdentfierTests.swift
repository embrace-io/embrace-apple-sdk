//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommon

class LogIdentifierTests: XCTestCase {
    func test_init_withUUID() throws {
        let value = UUID()
        let identifier = LogIdentifier(value: value)
        XCTAssertEqual(identifier.value, value)
    }

    func test_random_returnsNewValue() throws {
        XCTAssertNotEqual(LogIdentifier.random, LogIdentifier.random)
    }

    func test_encodeAndDecode_returnsSameValue() throws {
        let identifier = LogIdentifier(value: try XCTUnwrap(UUID(uuidString: "53B55EDD-889A-4876-86BA-6798288B609C")))
        let dataFromIdentifier = try JSONEncoder().encode(identifier)
        let decodedIdentifier = try JSONDecoder().decode(LogIdentifier.self, from: dataFromIdentifier)
        XCTAssertEqual(identifier, decodedIdentifier)
    }

    func test_encode_encodesValueAsUUID() throws {
        let identifier = LogIdentifier(value: try XCTUnwrap(UUID(uuidString: "53B55EDD-889A-4876-86BA-6798288B609C")))
        let dataFromIdentifier = try JSONEncoder().encode(identifier)
        XCTAssertEqual(String(data: dataFromIdentifier, encoding: .utf8), "\"53B55EDD-889A-4876-86BA-6798288B609C\"")
    }

}
