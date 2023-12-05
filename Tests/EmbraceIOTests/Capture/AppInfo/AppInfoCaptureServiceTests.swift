//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
import EmbraceCrash
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

final class MockCollectedResourceHandler: CaptureServiceResourceHandlerType {
    func addResource(key: String, value: String) throws {
        addedStrings[key] = value
    }

    func addResource(key: String, value: Int) throws {
        addedInts[key] = value
    }

    func addResource(key: String, value: Double) throws {
        addedDoubles[key] = value
    }

    var addedStrings: [String: String] = [:]
    var addedInts: [String: Int] = [:]
    var addedDoubles: [String: Double] = [:]
}
