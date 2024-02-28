//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

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
            key: DeviceResourceKey.OSVersion.rawValue,
            value: .string(EMBDevice.operatingSystemVersion)
        )

        // os build
        addResource(
            key: DeviceResourceKey.OSBuild.rawValue,
            value: .string(EMBDevice.operatingSystemBuild)
        )

        // os variant
        addResource(
            key: DeviceResourceKey.osVariant.rawValue,
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
