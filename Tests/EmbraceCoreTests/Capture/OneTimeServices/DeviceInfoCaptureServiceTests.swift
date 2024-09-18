//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceObjCUtilsInternal
import EmbraceStorageInternal

final class DeviceInfoCaptureServiceTests: XCTestCase {

    func test_started() throws {
        // given an device info capture service
        let service = DeviceInfoCaptureService()
        let handler = try EmbraceStorage.createInMemoryDb()
        service.handler = handler

        // when the service is installed and started
        service.install(otel: nil)
        service.start()

        // then the app info resources are correctly stored
        let processId = ProcessIdentifier.current.hex

        let resources = try handler.fetchResourcesForProcessId(.current)
        XCTAssertEqual(resources.count, 11)

        // jailbroken
        let jailbroken = try handler.fetchMetadata(
            key: DeviceResourceKey.isJailbroken.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(jailbroken)
        XCTAssertEqual(jailbroken!.stringValue, "false")

        // locale
        let locale = try handler.fetchMetadata(
            key: DeviceResourceKey.locale.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(locale)
        XCTAssertEqual(locale!.stringValue, EMBDevice.locale)

        // timezone
        let timezone = try handler.fetchMetadata(
            key: DeviceResourceKey.timezone.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(timezone)
        XCTAssertEqual(timezone!.stringValue, EMBDevice.timezoneDescription)

        // disk space
        let diskSpace = try handler.fetchMetadata(
            key: DeviceResourceKey.totalDiskSpace.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(diskSpace)
        XCTAssertEqual(diskSpace!.integerValue, EMBDevice.totalDiskSpace.intValue)

        // os version
        let osVersion = try handler.fetchMetadata(
            key: DeviceResourceKey.osVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osVersion)
        XCTAssertEqual(osVersion!.stringValue, EMBDevice.operatingSystemVersion)

        // os build
        let osBuild = try handler.fetchMetadata(
            key: DeviceResourceKey.osBuild.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osBuild)
        XCTAssertEqual(osBuild!.stringValue, EMBDevice.operatingSystemBuild)

        // os variant
        let osVariant = try handler.fetchMetadata(
            key: DeviceResourceKey.osVariant.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osVariant)
        XCTAssertEqual(osVariant!.stringValue, EMBDevice.operatingSystemType)

        // model
        let model = try handler.fetchMetadata(
            key: DeviceResourceKey.model.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )

        XCTAssertNotNil(model)
        XCTAssertEqual(model!.stringValue, EMBDevice.model)

        // osType
        let osType = try handler.fetchMetadata(
            key: DeviceResourceKey.osType.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osType)
        XCTAssertEqual(try XCTUnwrap(osType?.stringValue), "darwin")

        // osName
        let osName = try handler.fetchMetadata(
            key: DeviceResourceKey.osName.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osName)
        XCTAssertEqual(try XCTUnwrap(osName?.stringValue), EMBDevice.operatingSystemType)

        // osName
        let architecture = try handler.fetchMetadata(
            key: DeviceResourceKey.architecture.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(architecture)
        XCTAssertEqual(try XCTUnwrap(architecture?.stringValue), EMBDevice.architecture)
    }

    func test_notStarted() throws {
        // given an app info capture service
        let service = AppInfoCaptureService()
        let handler = try EmbraceStorage.createInMemoryDb()
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
