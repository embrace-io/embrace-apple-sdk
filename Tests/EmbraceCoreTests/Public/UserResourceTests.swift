//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceStorage

final class UserResourceTests: XCTestCase {

    var storage: EmbraceStorage?
    var subject: UserResource!

    // dummy data for tests
    let xUsername = "example"
    let xEmail = "test@example.com"
    let xIdentifier = "091232"

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        subject = UserResource(storage: storage!)
    }

    override func tearDownWithError() throws {
        try storage?.teardown()
    }

    // MARK: - Retrieving data

    func test_properties_areNil_ifNoRecords() throws {
        XCTAssertNil(subject.username)
        XCTAssertNil(subject.email)
        XCTAssertNil(subject.identifier)
    }

    func test_username_isSet_ifRecordPresent() throws {
        let record = ResourceRecord(key: UserResourceKey.username.rawValue, value: xUsername)
        try storage?.upsertResource(record)

        XCTAssertEqual(subject.username, xUsername)
    }

    func test_email_isSet_ifRecordPresent() throws {
        let record = ResourceRecord(key: UserResourceKey.email.rawValue, value: xEmail)
        try storage?.upsertResource(record)

        XCTAssertEqual(subject.email, xEmail)
    }

    func test_identifier_isSet_ifRecordPresent() throws {
        let record = ResourceRecord(key: UserResourceKey.identifier.rawValue, value: xIdentifier)
        try storage?.upsertResource(record)

        XCTAssertEqual(subject.identifier, xIdentifier)
    }

    // MARK: nil EmbraceStorage

    func test_username_isNil_ifStorage_isNil() throws {
        let record = ResourceRecord(key: UserResourceKey.username.rawValue, value: xUsername)
        try storage?.upsertResource(record)

        storage = nil

        XCTAssertNil(subject.username)
    }

    func test_email_isNil_ifStorage_isNil() throws {
        let record = ResourceRecord(key: UserResourceKey.email.rawValue, value: xUsername)
        try storage?.upsertResource(record)

        storage = nil

        XCTAssertNil(subject.email)
    }

    func test_identifier_isNil_ifStorage_isNil() throws {
        let record = ResourceRecord(key: UserResourceKey.identifier.rawValue, value: xUsername)
        try storage?.upsertResource(record)

        storage = nil

        XCTAssertNil(subject.identifier)
    }

    // MARK: - Writing data
    func test_setUsername_createsRecord() throws {
        subject.username = xUsername

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.username.rawValue)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.stringValue, xUsername)
    }

    func test_setEmail_createsRecord() throws {
        subject.email = xEmail

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.email.rawValue)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.stringValue, xEmail)
    }

    func test_setIdentifier_createsRecord() throws {
        subject.identifier = xIdentifier

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.identifier.rawValue)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.stringValue, xIdentifier)
    }

    // MARK: Ill-formatted

    func test_setEmail_notValidEmail_createsRecord() throws {
        let invalidEmail = "o1234512"
        subject.email = invalidEmail

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.email.rawValue)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.stringValue, invalidEmail)
    }

    // MARK: - Removing data
    func test_setUsername_toNil_removesRecord() throws {
        let initial = ResourceRecord(key: UserResourceKey.username.rawValue, value: xUsername)
        try storage?.upsertResource(initial)
        XCTAssertEqual(subject.username, xUsername)

        subject.username = nil

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.username.rawValue)
        XCTAssertNil(record)
    }

    func test_setEmail_toNil_removesRecord() throws {
        let initial = ResourceRecord(key: UserResourceKey.email.rawValue, value: xEmail)
        try storage?.upsertResource(initial)
        XCTAssertEqual(subject.email, xEmail)

        subject.email = nil

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.email.rawValue)
        XCTAssertNil(record)
    }

    func test_setIdentifier_toNil_removesRecord() throws {
        let initial = ResourceRecord(key: UserResourceKey.identifier.rawValue, value: xIdentifier)
        try storage?.upsertResource(initial)
        XCTAssertEqual(subject.identifier, xIdentifier)

        subject.identifier = nil

        let record = try storage?.fetchPermanentResource(key: UserResourceKey.identifier.rawValue)
        XCTAssertNil(record)
    }

    // MARK: Clear
    func test_clear_doesNothing_ifNothingSet() throws {
        XCTAssertNil(subject.username)
        XCTAssertNil(subject.email)
        XCTAssertNil(subject.identifier)

        subject.clear()

        XCTAssertNil(subject.username)
        XCTAssertNil(subject.email)
        XCTAssertNil(subject.identifier)
    }

    func test_clear_removesAllSetItems() throws {
        subject.username = xUsername

        subject.clear()

        XCTAssertNil(subject.username)
        XCTAssertNil(subject.email)
        XCTAssertNil(subject.identifier)
    }

    func test_clear_removesAllItems() throws {
        subject.username = xUsername
        subject.email = xEmail
        subject.identifier = xIdentifier

        subject.clear()

        XCTAssertNil(subject.username)
        XCTAssertNil(subject.email)
        XCTAssertNil(subject.identifier)
    }

}
