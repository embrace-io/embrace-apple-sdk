//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommon
import EmbraceObjCUtils
import EmbraceStorage

final class AppInfoCaptureServiceTests: XCTestCase {

    func test_started() throws {
        // given an app info capture service
        let service = AppInfoCaptureService()
        let handler = try EmbraceStorage.createInDiskDb()
        service.handler = handler

        // when the service is installed and started
        service.install(otel: nil)
        service.start()

        // then the app info resources are correctly stored
        let processId = ProcessIdentifier.current.hex

        // bundle version
        let bundleVersion = try handler.fetchMetadata(
            key: AppResourceKey.bundleVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(bundleVersion)
        XCTAssertEqual(bundleVersion!.stringValue, EMBDevice.bundleVersion)

        // environment
        let environment = try handler.fetchMetadata(
            key: AppResourceKey.environment.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(environment)
        XCTAssertEqual(environment!.stringValue, EMBDevice.environment)

        // environment detail
        let environmentDetail = try handler.fetchMetadata(
            key: AppResourceKey.detailedEnvironment.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(environmentDetail)
        XCTAssertEqual(environmentDetail!.stringValue, EMBDevice.environmentDetail)

        // framework
        let framework = try handler.fetchMetadata(
            key: AppResourceKey.framework.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(framework)
        XCTAssertEqual(framework!.integerValue, -1)

        // sdk version
        let sdkVersion = try handler.fetchMetadata(
            key: AppResourceKey.sdkVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(sdkVersion)
        XCTAssertEqual(sdkVersion!.stringValue, EmbraceMeta.sdkVersion)

        // app version
        let appVersion = try handler.fetchMetadata(
            key: AppResourceKey.appVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(appVersion)
        XCTAssertEqual(appVersion!.stringValue, EMBDevice.appVersion)

        // process identifier
        let processIdentifier = try handler.fetchMetadata(
            key: AppResourceKey.processIdentifier.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(processIdentifier)
        XCTAssertEqual(processIdentifier!.stringValue, ProcessIdentifier.current.hex)
    }

    func test_notStarted() throws {
        // given an app info capture service
        let service = AppInfoCaptureService()
        let handler = try EmbraceStorage.createInDiskDb()
        service.handler = handler

        // when the service is installed but not started
        service.install(otel: nil)

        // then no resources are captured
        let expectation = XCTestExpectation()
        try handler.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
