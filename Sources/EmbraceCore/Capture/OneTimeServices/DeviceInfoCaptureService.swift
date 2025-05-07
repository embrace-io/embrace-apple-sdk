//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceObjCUtilsInternal
#endif
import OpenTelemetrySdk

class DeviceInfoCaptureService: ResourceCaptureService {

    override func onStart() {
        // jailbroken
        addResource(
            key: DeviceResourceKey.isJailbroken.rawValue,
            value: .string(String(EMBDevice.isJailbroken))
        )

        // locale
        addResource(
            key: DeviceResourceKey.locale.rawValue,
            value: .string(EMBDevice.locale)
        )

        // timezone
        addResource(
            key: DeviceResourceKey.timezone.rawValue,
            value: .string(EMBDevice.timezoneDescription)
        )

        // disk space
        addResource(
            key: DeviceResourceKey.totalDiskSpace.rawValue,
            value: .int(EMBDevice.totalDiskSpace.intValue)
        )

        // os version
        addResource(
            key: ResourceAttributes.osVersion.rawValue,
            value: .string(EMBDevice.operatingSystemVersion)
        )

        // os build
        addResource(
            key: DeviceResourceKey.osBuild.rawValue,
            value: .string(EMBDevice.operatingSystemBuild)
        )

        // os variant
        addResource(
            key: DeviceResourceKey.osVariant.rawValue,
            value: .string(EMBDevice.operatingSystemType)
        )

        // os type
        // Should always be "darwin" as can be seen in semantic convention docs:
        // https://opentelemetry.io/docs/specs/semconv/resource/os/
        addResource(
            key: ResourceAttributes.osType.rawValue,
            value: .string("darwin")
        )

        addResource(
            key: ResourceAttributes.osName.rawValue,
            value: .string(EMBDevice.operatingSystemType)
        )

        // model
        addResource(
            key: ResourceAttributes.deviceModelIdentifier.rawValue,
            value: .string(EMBDevice.model)
        )

        // architecture
        addResource(
            key: DeviceResourceKey.architecture.rawValue,
            value: .string(EMBDevice.architecture)
        )
    }
}
