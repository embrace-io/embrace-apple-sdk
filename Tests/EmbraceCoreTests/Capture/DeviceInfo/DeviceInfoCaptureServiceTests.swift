//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCrash
import EmbraceCommon
import EmbraceObjCUtils

final class DeviceInfoCaptureServiceTests: XCTestCase {
    func test_collectingDeviceInformation() {
        // Given a Device Info collector is created.
        let mockHandler = MockCollectedResourceHandler()
        let deviceInfoCollector = DeviceInfoCaptureService(resourceHandler: mockHandler)

        // When called to collect data.
        deviceInfoCollector.start()

        // All the correct data should've been collected.
        XCTAssertEqual(mockHandler.addedStrings["os.version"], EMBDevice.operatingSystemVersion)
        XCTAssertEqual(mockHandler.addedStrings["device.locale"], EMBDevice.locale)
        XCTAssertEqual(mockHandler.addedStrings["device.is_jailbroken"], String(EMBDevice.isJailbroken))
        XCTAssertEqual(mockHandler.addedStrings["device.timezone"], EMBDevice.timezoneDescription)
        XCTAssertEqual(mockHandler.addedStrings["os.build_id"], EMBDevice.operatingSystemBuild)
        XCTAssertEqual(mockHandler.addedInts["device.disk_size"], EMBDevice.totalDiskSpace.intValue)

        XCTAssertNotNil(mockHandler.addedStrings["os.version"])
        XCTAssertNotNil(mockHandler.addedStrings["device.locale"])
        XCTAssertNotNil(mockHandler.addedStrings["device.is_jailbroken"])
        XCTAssertNotNil(mockHandler.addedStrings["device.timezone"])
        XCTAssertNotNil(mockHandler.addedStrings["os.build_id"])
        XCTAssertNotNil(mockHandler.addedInts["device.disk_size"])
    }
}
