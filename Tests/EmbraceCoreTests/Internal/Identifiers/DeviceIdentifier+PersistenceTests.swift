//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
import EmbraceStorageInternal
@testable import EmbraceCore
import EmbraceCommonInternal

class DeviceIdentifier_PersistenceTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        KeychainAccess.keychain = AlwaysSuccessfulKeychainInterface()

        // delete the resource if we already have it
        if let resource = try storage.fetchRequiredPermanentResource(key: DeviceIdentifier.resourceKey) {
            try storage.delete(record: resource)
        }
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_retrieve_withNoRecordInStorage_shouldCreateNewPermanentRecord() throws {
        let result = DeviceIdentifier.retrieve(from: storage)

        let resourceRecord = try storage.fetchRequiredPermanentResource(key: DeviceIdentifier.resourceKey)
        XCTAssertNotNil(resourceRecord)
        XCTAssertEqual(resourceRecord?.lifespan, .permanent)

        let storedDeviceId = try XCTUnwrap(resourceRecord?.uuidValue)
        XCTAssertEqual(result, DeviceIdentifier(value: storedDeviceId))
    }

    func test_retrieve_withNoRecordInStorage_shouldRequestFromKeychain() throws {
        // because of our setup we could assume there is no database entry but lets make sure
        // to delete the resource if we already have it
        if let resource = try storage.fetchRequiredPermanentResource(key: DeviceIdentifier.resourceKey) {
            try storage.delete(record: resource)
        }
        let keychainDeviceId = KeychainAccess.deviceId

        let result = DeviceIdentifier.retrieve(from: storage)
        XCTAssertEqual(result, DeviceIdentifier(value: keychainDeviceId))
    }

    func test_retrieve_withRecordInStorage_shouldReturnStorageValue() throws {
        // because of our setup we could assume there is no database entry but lets make sure
        // to delete the resource if we already have it

        let deviceId = DeviceIdentifier(value: UUID())

        try storage.addMetadata(
            key: DeviceIdentifier.resourceKey,
            value: deviceId.hex,
            type: .requiredResource,
            lifespan: .permanent
        )

        let result = DeviceIdentifier.retrieve(from: storage)
        XCTAssertEqual(result, deviceId)
    }
}
