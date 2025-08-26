//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
#endif

class DeviceInfoCaptureService: ResourceCaptureService {

    override func onStart() {

        let criticalResources: [String: String] = [
            // os type
            // Should always be "darwin" as can be seen in semantic convention docs:
            // https://opentelemetry.io/docs/specs/semconv/resource/os/
            DeviceResourceKey.osType.rawValue: "darwin",

            // os variant
            DeviceResourceKey.osVariant.rawValue: EMBDevice.operatingSystemType
        ]

        let resourcesMap: [String: String] = [
            // jailbroken
            DeviceResourceKey.isJailbroken.rawValue: EMBDevice.isJailbroken ? "true" : "false",

            // locale
            DeviceResourceKey.locale.rawValue: EMBDevice.locale,

            // timezone
            DeviceResourceKey.timezone.rawValue: EMBDevice.timezoneDescription,

            // disk space
            DeviceResourceKey.totalDiskSpace.rawValue: String(EMBDevice.totalDiskSpace.intValue),

            // os version
            DeviceResourceKey.osVersion.rawValue: EMBDevice.operatingSystemVersion,

            // os build
            DeviceResourceKey.osBuild.rawValue: EMBDevice.operatingSystemBuild,

            // model
            DeviceResourceKey.deviceModelIdentifier.rawValue: EMBDevice.model,

            // architecture
            DeviceResourceKey.architecture.rawValue: EMBDevice.architecture
        ]

        addCriticalResources(criticalResources)
        addRequiredResources(resourcesMap)
    }
}
