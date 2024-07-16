//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceObjCUtilsInternal

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
            key: DeviceResourceKey.osVersion.rawValue,
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
            key: DeviceResourceKey.osType.rawValue,
            value: .string("darwin")
        )

        addResource(
            key: DeviceResourceKey.osName.rawValue,
            value: .string(EMBDevice.operatingSystemType)
        )

        // resolution
        if let resolution = EMBDevice.screenResolution {
            addResource(
                key: DeviceResourceKey.screenResolution.rawValue,
                value: .string(resolution)
            )
        }

        // model
        addResource(
            key: DeviceResourceKey.model.rawValue,
            value: .string(EMBDevice.model)
        )
    }
}
