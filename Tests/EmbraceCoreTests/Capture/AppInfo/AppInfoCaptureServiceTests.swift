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
        XCTAssertEqual(mockHandler.addedStrings["emb.app.bundle_version"], EMBDevice.bundleVersion)
        XCTAssertEqual(mockHandler.addedStrings["emb.app.environment"], EMBDevice.environment)
        XCTAssertEqual(mockHandler.addedStrings["emb.app.environment_detailed"], EMBDevice.environmentDetail)
        XCTAssertEqual(mockHandler.addedStrings["emb.app.version"], EMBDevice.appVersion)

        XCTAssertNotNil(mockHandler.addedStrings["emb.app.bundle_version"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.app.environment"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.app.environment_detailed"])
        XCTAssertNotNil(mockHandler.addedStrings["emb.app.version"])
    }
}
