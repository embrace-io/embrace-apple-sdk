//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorage

final class UserInfoPayloadTests: XCTestCase {

    func test_userinfo_whenNothingSet_isEmpty() throws {
        let payload = UserInfoPayload(with: [])
        XCTAssertNil(payload.username)
        XCTAssertNil(payload.identifier)
        XCTAssertNil(payload.email)
    }

    func test_userinfo_whenNothingSet_encodesToEmptyJSON() throws {
        let payload = UserInfoPayload(with: [])

        let data = try JSONEncoder().encode(payload)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, #"{}"#)
    }

    func test_userinfo_whenUsernameSet_encodesToJSON() throws {
        let payload = UserInfoPayload(with: [
            ResourceRecord(key: UserResourceKey.username.rawValue, value: "test")
        ])

        let data = try JSONEncoder().encode(payload)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, #"{"un":"test"}"#)
    }

    func test_userinfo_whenEmailSet_encodesToJSON() throws {
        let payload = UserInfoPayload(with: [
            ResourceRecord(key: UserResourceKey.email.rawValue, value: "get@me.org")
        ])

        let data = try JSONEncoder().encode(payload)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, #"{"em":"get@me.org"}"#)
    }

    func test_userinfo_whenIdentifierSet_encodesToJSON() throws {
        let payload = UserInfoPayload(with: [
            ResourceRecord(key: UserResourceKey.identifier.rawValue, value: "1234")
        ])

        let data = try JSONEncoder().encode(payload)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, #"{"id":"1234"}"#)
    }

    func test_userinfo_whenEverythingSet_encodesToJSON() throws {
        let payload = UserInfoPayload(with: [
            ResourceRecord(key: UserResourceKey.username.rawValue, value: "test"),
            ResourceRecord(key: UserResourceKey.email.rawValue, value: "get@me.org"),
            ResourceRecord(key: UserResourceKey.identifier.rawValue, value: "1234")
        ])

        let data = try JSONEncoder().encode(payload)

        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(decoded["em"], "get@me.org")
        XCTAssertEqual(decoded["un"], "test")
        XCTAssertEqual(decoded["id"], "1234")
    }

}
