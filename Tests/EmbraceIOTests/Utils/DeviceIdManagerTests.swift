//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
import EmbraceStorage
@testable import EmbraceIO

class DeviceIdManagerTests: XCTestCase {

    var storage: EmbraceStorage?

    override func setUpWithError() throws {
        storage = try EmbraceStorage(options: testOptions)
        KeychainAccess.keychain = AlwaysSuccessfulKeychainInterface()
        // we should always have a storage, if not something bad is happening
        guard let storage = storage else {
            fatalError("failed to create storage for DeviceIdManagerTests in setup")
        }

        // delete the resource if we already have it
        if let resource = try storage.fetchResource(key: "device.id") {
            try storage.delete(record: resource)
        }
    }

    let testOptions = EmbraceStorage.Options(baseUrl: URL(fileURLWithPath: NSTemporaryDirectory()), fileName: "test.sqlite")

    func test_if_new_deviceId_requested_should_be_in_database() throws {

        guard let storage = storage else {
            fatalError("failed to create storage for DeviceIdManagerTests")
        }

        let deviceId = EmbraceDeviceId.retrieve(from: storage)

        let resourceRecord = try storage.fetchResource(key: "device.id")
        XCTAssertNotNil(resourceRecord)
        let storedDeviceId = UUID(uuidString: resourceRecord!.value)

        XCTAssertEqual(deviceId, storedDeviceId)
    }

    func test_if_no_database_entry_should_get_from_keychain() throws {
        guard let storage = storage else {
            fatalError("failed to create storage for DeviceIdManagerTests")
        }

        // because of our setup we could assume there is no database entry but lets make sure
        // delete the resource if we already have it
        if let resource = try storage.fetchResource(key: "device.id") {
            try storage.delete(record: resource)
        }

        let keychainDeviceId = KeychainAccess.deviceId
        let managerDeviceId = EmbraceDeviceId.retrieve(from: storage)

        XCTAssertEqual(keychainDeviceId, managerDeviceId)
    }
}
