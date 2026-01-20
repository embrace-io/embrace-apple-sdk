//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import Foundation
import TestSupport
import XCTest

@testable import EmbraceCore

class DeviceIdentifier_PersistenceTests: XCTestCase {

    let fileProvider = TemporaryFilepathProvider()
    var fileURL: URL!

    override func setUpWithError() throws {
        KeychainAccess.keychain = AlwaysSuccessfulKeychainInterface()

        try? FileManager.default.removeItem(at: fileProvider.tmpDirectory)

        fileURL = fileProvider.fileURL(for: "DeviceIdentifier_PersistenceTests", name: "file")!
        try? FileManager.default.createDirectory(
            at: fileProvider.directoryURL(for: "DeviceIdentifier_PersistenceTests")!, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {

    }

    func test_retrieve_withNoFile_shouldCreateNewFile() throws {
        let result = EmbraceIdentifier.retrieveDeviceId(fileURL: fileURL)

        XCTAssert(FileManager.default.fileExists(atPath: fileURL.path))

        let value = try String(contentsOf: fileURL)
        XCTAssert(value.count > 0)

        let storedDeviceId = UUID(uuidString: value)
        XCTAssertNotNil(storedDeviceId)
        XCTAssertEqual(result, DeviceIdentifier(value: storedDeviceId!))
    }

    func test_retrieve_withNoFile_shouldRequestFromKeychain() throws {
        #if os(macOS)
            try XCTSkipIf(true, "Failed on macOS for some reason")
        #endif
        let keychainDeviceId = KeychainAccess.deviceId

        let result = EmbraceIdentifier.retrieveDeviceId(fileURL: fileURL)
        XCTAssertEqual(result, DeviceIdentifier(value: keychainDeviceId))
    }

    func test_retrieve_withFile_shouldReturnFileValue() throws {

        let uuid = UUID()
        let deviceId = DeviceIdentifier(value: uuid)

        try uuid.uuidString.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = EmbraceIdentifier.retrieveDeviceId(fileURL: fileURL)
        XCTAssertEqual(result, deviceId)
    }
}
