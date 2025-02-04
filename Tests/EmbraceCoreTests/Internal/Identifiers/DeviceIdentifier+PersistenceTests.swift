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
        if let resource = storage.fetchRequiredPermanentResource(key: DeviceIdentifier.resourceKey) {
            storage.delete(resource)
        }
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

    func test_retrieve_withNoRecordInStorage_shouldCreateNewPermanentRecord() throws {
        let result = DeviceIdentifier.retrieve(from: storage)

        let resourceRecord = storage.fetchRequiredPermanentResource(key: DeviceIdentifier.resourceKey)
        XCTAssertNotNil(resourceRecord)
        XCTAssertEqual(resourceRecord?.lifespan, .permanent)

        let storedDeviceId = UUID(withoutHyphen: resourceRecord!.value)!
        XCTAssertEqual(result, DeviceIdentifier(value: storedDeviceId))
    }

    func test_retrieve_withNoRecordInStorage_shouldRequestFromKeychain() throws {
        // because of our setup we could assume there is no database entry but lets make sure
        // to delete the resource if we already have it
        if let resource = storage.fetchRequiredPermanentResource(key: DeviceIdentifier.resourceKey) {
            storage.delete(resource)
        }
        let keychainDeviceId = KeychainAccess.deviceId

        let result = DeviceIdentifier.retrieve(from: storage)
        XCTAssertEqual(result, DeviceIdentifier(value: keychainDeviceId))
    }

    func test_retrieve_withRecordInStorage_shouldReturnStorageValue() throws {
        // because of our setup we could assume there is no database entry but lets make sure
        // to delete the resource if we already have it

        let deviceId = DeviceIdentifier(value: UUID())

        storage.addMetadata(
            key: DeviceIdentifier.resourceKey,
            value: deviceId.hex,
            type: .requiredResource,
            lifespan: .permanent
        )

        let result = DeviceIdentifier.retrieve(from: storage)
        XCTAssertEqual(result, deviceId)
    }
}
