//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
import EmbraceStorage
@testable import EmbraceCore

class DeviceIdManagerTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInDiskDb()
        KeychainAccess.keychain = AlwaysSuccessfulKeychainInterface()

        // delete the resource if we already have it
        if let resource = try storage.fetchPermanentResource(key: "device.id") {
            try storage.delete(record: resource)
        }
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_if_new_deviceId_requested_should_be_in_database() throws {
        let deviceId = EmbraceDeviceId.retrieve(from: storage)

        let resourceRecord = try storage.fetchPermanentResource(key: "device.id")
        XCTAssertNotNil(resourceRecord)
        let storedDeviceId = resourceRecord?.uuidValue

        XCTAssertEqual(deviceId, storedDeviceId)
    }

    func test_if_no_database_entry_should_get_from_keychain() throws {
        // because of our setup we could assume there is no database entry but lets make sure
        // delete the resource if we already have it
        if let resource = try storage.fetchPermanentResource(key: "device.id") {
            try storage.delete(record: resource)
        }

        let keychainDeviceId = KeychainAccess.deviceId
        let managerDeviceId = EmbraceDeviceId.retrieve(from: storage)

        XCTAssertEqual(keychainDeviceId, managerDeviceId)
    }
}
