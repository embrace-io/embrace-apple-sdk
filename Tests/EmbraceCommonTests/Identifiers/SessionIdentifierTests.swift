//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCommon

final class SessionIdentifierTests: XCTestCase {

    func test_init_withUUID() throws {
        let value = UUID()
        let sessionIdentifier = SessionIdentifier(value: value)
        XCTAssertEqual(sessionIdentifier.value, value)
    }

    func test_init_withString() throws {
        let value = UUID()
        let sessionIdentifier = SessionIdentifier(string: value.uuidString)
        XCTAssertEqual(sessionIdentifier?.value, value)
    }

    func test_init_withWithInvalidString_isNil() throws {
        XCTAssertNil(SessionIdentifier(string: "Hello World"))
    }

    func test_random_returnsNewValue() throws {
        XCTAssertNotEqual(SessionIdentifier.random, SessionIdentifier.random)
    }

    func test_encodeAndDecode_returnsSameValue() throws {
        let sessionId = SessionIdentifier.random
        let data = try JSONEncoder().encode(sessionId)
        let decoded = try JSONDecoder().decode(SessionIdentifier.self, from: data)
        XCTAssertEqual(sessionId, decoded)
    }

    func test_encode_encodesValueAsUUID() throws {
        let sessionId = SessionIdentifier(string: "53B55EDD-889A-4876-86BA-6798288B609C")!
        let data = try JSONEncoder().encode(sessionId)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"53B55EDD-889A-4876-86BA-6798288B609C\"")
    }

}
