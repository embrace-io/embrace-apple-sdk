//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
@_implementationOnly import EmbraceObjCUtilsInternal
import EmbraceStorageInternal
import OpenTelemetrySdk

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

        let resources = handler.fetchResourcesForProcessId(.current)
        XCTAssertEqual(resources.count, 11)

        // jailbroken
        let jailbroken = handler.fetchMetadata(
            key: DeviceResourceKey.isJailbroken.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(jailbroken)
        XCTAssertEqual(jailbroken!.value, "false")

        // locale
        let locale = handler.fetchMetadata(
            key: DeviceResourceKey.locale.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(locale)
        XCTAssertEqual(locale!.value, EMBDevice.locale)

        // timezone
        let timezone = handler.fetchMetadata(
            key: DeviceResourceKey.timezone.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(timezone)
        XCTAssertEqual(timezone!.value, EMBDevice.timezoneDescription)

        // disk space
        let diskSpace = handler.fetchMetadata(
            key: DeviceResourceKey.totalDiskSpace.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(diskSpace)
        XCTAssertEqual(diskSpace!.value, String(EMBDevice.totalDiskSpace.intValue))

        // os version
        let osVersion = handler.fetchMetadata(
            key: ResourceAttributes.osVersion.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osVersion)
        XCTAssertEqual(osVersion!.value, EMBDevice.operatingSystemVersion)

        // os build
        let osBuild = handler.fetchMetadata(
            key: DeviceResourceKey.osBuild.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osBuild)
        XCTAssertEqual(osBuild!.value, EMBDevice.operatingSystemBuild)

        // os variant
        let osVariant = handler.fetchMetadata(
            key: DeviceResourceKey.osVariant.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osVariant)
        XCTAssertEqual(osVariant!.value, EMBDevice.operatingSystemType)

        // model
        let model = handler.fetchMetadata(
            key: ResourceAttributes.deviceModelIdentifier.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )

        XCTAssertNotNil(model)
        XCTAssertEqual(model!.value, EMBDevice.model)

        // osType
        let osType = handler.fetchMetadata(
            key: ResourceAttributes.osType.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osType)
        XCTAssertEqual(osType!.value, "darwin")

        // osName
        let osName = handler.fetchMetadata(
            key: ResourceAttributes.osName.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(osName)
        XCTAssertEqual(osName!.value, EMBDevice.operatingSystemType)

        // osName
        let architecture = handler.fetchMetadata(
            key: DeviceResourceKey.architecture.rawValue,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: processId
        )
        XCTAssertNotNil(architecture)
        XCTAssertEqual(architecture!.value, EMBDevice.architecture)
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
