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

    func setValue(service: CFString, account: CFString, value: String) -> OSStatus {
        self.value = value
        return errSecSuccess
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
}
