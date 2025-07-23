//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    @_implementationOnly import EmbraceObjCUtilsInternal
#endif

class DeviceInfoCaptureService: ResourceCaptureService {

    override func onStart() {

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
            ResourceAttributes.osVersion.rawValue: EMBDevice.operatingSystemVersion,

            // os build
            DeviceResourceKey.osBuild.rawValue: EMBDevice.operatingSystemBuild,

            // os variant
            DeviceResourceKey.osVariant.rawValue: EMBDevice.operatingSystemType,

            // os type
            // Should always be "darwin" as can be seen in semantic convention docs:
            // https://opentelemetry.io/docs/specs/semconv/resource/os/
            ResourceAttributes.osType.rawValue: "darwin",

            // model
            ResourceAttributes.deviceModelIdentifier.rawValue: EMBDevice.model,

            // architecture
            DeviceResourceKey.architecture.rawValue: EMBDevice.architecture
        ]

        addRequiredResources(resourcesMap)
    }
}
