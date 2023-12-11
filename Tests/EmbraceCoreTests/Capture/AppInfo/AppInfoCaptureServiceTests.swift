//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommon
import EmbraceObjCUtils

final class AppInfoCaptureServiceTests: XCTestCase {
    func test_collectingAppInformation() {
        // Given an App Info collector is created.
        let mockHandler = MockCollectedResourceHandler()
        let appInfoCollector = AppInfoCaptureService(resourceHandler: mockHandler)

        // When called to collect data.
        appInfoCollector.start()

        // All the correct data should've been collected.
        XCTAssertEqual(mockHandler.addedStrings["app.build_uuid"], EMBDevice.buildUUID)
        XCTAssertEqual(mockHandler.addedStrings["app.bundle_version"], EMBDevice.bundleVersion)
        XCTAssertEqual(mockHandler.addedStrings["app.environment"], EMBDevice.environment)
        XCTAssertEqual(mockHandler.addedStrings["app.environment_detailed"], EMBDevice.environmentDetail)
        XCTAssertEqual(mockHandler.addedStrings["app.version"], EMBDevice.appVersion)
        XCTAssertEqual(mockHandler.addedStrings["app.bundle_id"], Bundle.main.bundleIdentifier)

        XCTAssertNotNil(mockHandler.addedStrings["app.build_uuid"])
        XCTAssertNotNil(mockHandler.addedStrings["app.bundle_version"])
        XCTAssertNotNil(mockHandler.addedStrings["app.environment"])
        XCTAssertNotNil(mockHandler.addedStrings["app.environment_detailed"])
        XCTAssertNotNil(mockHandler.addedStrings["app.version"])
        XCTAssertNotNil(mockHandler.addedStrings["app.bundle_id"])
    }
}
