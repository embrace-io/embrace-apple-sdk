//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
@_implementationOnly import EmbraceObjCUtilsInternal
import EmbraceStorageInternal

final class AppInfoCaptureServiceTests: XCTestCase {

    func test_started() throws {
        // given an app info capture service
        let service = AppInfoCaptureService()
        let handler = try EmbraceStorage.createInMemoryDb()
        service.handler = handler

        // when the service is installed and started
        service.install(otel: nil)
        service.start()

        // then the app info resources are correctly stored
        let processId = ProcessIdentifier.current.hex

        // bundle version
        let bundleVersion = handler.fetchMetadata(
            key: AppResourceKey.bundleVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(bundleVersion)
        XCTAssertEqual(bundleVersion!.value, EMBDevice.bundleVersion)

        // environment
        let environment = handler.fetchMetadata(
            key: AppResourceKey.environment.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(environment)
        XCTAssertEqual(environment!.value, EMBDevice.environment)

        // environment detail
        let environmentDetail = handler.fetchMetadata(
            key: AppResourceKey.detailedEnvironment.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(environmentDetail)
        XCTAssertEqual(environmentDetail!.value, EMBDevice.environmentDetail)

        // framework
        let framework = handler.fetchMetadata(
            key: AppResourceKey.framework.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(framework)
        XCTAssertEqual(framework!.value, "-1")

        // sdk version
        let sdkVersion = handler.fetchMetadata(
            key: AppResourceKey.sdkVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(sdkVersion)
        XCTAssertEqual(sdkVersion!.value, EmbraceMeta.sdkVersion)

        // app version
        let appVersion = handler.fetchMetadata(
            key: AppResourceKey.appVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(appVersion)
        XCTAssertEqual(appVersion!.value, EMBDevice.appVersion)

        // process identifier
        let processIdentifier = handler.fetchMetadata(
            key: AppResourceKey.processIdentifier.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(processIdentifier)
        XCTAssertEqual(processIdentifier!.value, ProcessIdentifier.current.hex)
    }

    func test_notStarted() throws {
        // given an app info capture service
        let service = AppInfoCaptureService()
        let handler = try EmbraceStorage.createInMemoryDb()
        service.handler = handler

        // when the service is installed but not started
        service.install(otel: nil)

        // then no resources are captured
        let metadata: [MetadataRecord] = handler.fetchAll()
        XCTAssertEqual(metadata.count, 0)
    }
}
