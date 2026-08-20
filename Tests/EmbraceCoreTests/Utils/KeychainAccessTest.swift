//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceCore

class AlwaysSuccessfulKeychainInterface: KeychainInterface {
    var value: String?

    func valueFor(service: CFString, account: CFString) -> (value: String?, status: OSStatus) {
        return (value, errSecSuccess)
    }

    func setValue(service: CFString, account: CFString, value: String, completion: (OSStatus) -> Void) {
        self.value = value
        completion(errSecSuccess)
    }

    func deleteValue(service: CFString, account: CFString) -> OSStatus {
        value = nil
        return errSecSuccess
    }
}

class KeychainAccessTests: XCTestCase {

    let mockKeyChain = AlwaysSuccessfulKeychainInterface()

    override func setUpWithError() throws {
        KeychainAccess.keychain = mockKeyChain
    }

    func test_loadSavedDeviceId_returnsMatchingId() {
        let deviceId = KeychainAccess.deviceId
        let deviceId2 = KeychainAccess.deviceId

        XCTAssertEqual(deviceId, deviceId2)
    }

    func test_deviceId_returnsId() {
        let deviceId = KeychainAccess.deviceId

        XCTAssertNotNil(deviceId)
    }

    func test_deviceId_withNonUUIDStoredValue_selfHealsToNewUUID() {
        // given a keychain holding a corrupt (non-UUID) value
        mockKeyChain.value = "not-a-uuid"

        // when reading the device id
        let deviceId = KeychainAccess.deviceId

        // then a fresh valid UUID is generated and persisted over the garbage
        XCTAssertEqual(mockKeyChain.value, deviceId.uuidString)
        XCTAssertNotEqual(mockKeyChain.value, "not-a-uuid")
    }

    func test_deviceId_whenWriteFails_returnsFreshValidIdEachTime() {
        // given a keychain that has nothing stored and whose writes fail
        KeychainAccess.keychain = FailingWriteKeychainInterface()

        // when reading the device id twice
        let id1 = KeychainAccess.deviceId
        let id2 = KeychainAccess.deviceId

        // then each call still returns a valid UUID; the failed write means nothing persists,
        // so the ids differ (the call never crashes or returns a stale/invalid value)
        XCTAssertNotEqual(id1, id2)
    }
}

private class FailingWriteKeychainInterface: KeychainInterface {
    func valueFor(service: CFString, account: CFString) -> (value: String?, status: OSStatus) {
        return (nil, errSecItemNotFound)
    }

    func setValue(service: CFString, account: CFString, value: String, completion: (OSStatus) -> Void) {
        completion(errSecIO)
    }

    func deleteValue(service: CFString, account: CFString) -> OSStatus {
        return errSecSuccess
    }
}
