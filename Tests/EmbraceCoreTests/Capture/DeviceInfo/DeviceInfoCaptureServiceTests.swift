//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
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
        XCTAssertEqual(mockHandler.addedStrings["emb.os.version"], EMBDevice.operatingSystemVersion)
        XCTAssertEqual(mockHandler.addedStrings["emb.device.locale"], EMBDevice.locale)
        XCTAssertEqual(mockHandler.addedStrings["emb.device.is_jailbroken"], String(EMBDevice.isJailbroken))
        XCTAssertEqual(mockHandler.addedStrings["emb.device.timezone"], EMBDevice.timezoneDescription)
        XCTAssertEqual(mockHandler.addedStrings["emb.os.build_id"], EMBDevice.operatingSystemBuild)
        XCTAssertEqual(mockHandler.addedInts["emb.device.disk_size"], EMBDevice.totalDiskSpace.intValue)

        XCTAssertNotNil(mockHandler.addedStrings["emb.os.version"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.device.locale"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.device.is_jailbroken"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.device.timezone"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.os.build_id"])
        XCTAssertNotNil(mockHandler.addedInts["emb.device.disk_size"])
    }
}
