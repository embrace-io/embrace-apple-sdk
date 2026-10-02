//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
#endif

class DeviceInfoCaptureService: ResourceCaptureService {

    /// Device resources the backend requires on every payload.
    /// These are not captured by `onStart()`, they are persisted by the SDK during `Embrace.init`
    /// so they are guaranteed to be stored before any other telemetry is.
    static var criticalResources: [String: String] {
        [
            // os type
            // Should always be "darwin" as can be seen in semantic convention docs:
            // https://opentelemetry.io/docs/specs/semconv/resource/os/
            SemanticConventions.Os.type.rawValue: "darwin",

            // os variant
            DeviceResourceKey.osVariant.rawValue: EMBDevice.operatingSystemType,
            SemanticConventions.Os.name.rawValue: EMBDevice.operatingSystemType
        ]
    }

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
            SemanticConventions.Os.version.rawValue: EMBDevice.operatingSystemVersion,

            // os build
            DeviceResourceKey.osBuild.rawValue: EMBDevice.operatingSystemBuild,

            // model
            SemanticConventions.Device.modelIdentifier.rawValue: EMBDevice.model,

            // architecture
            DeviceResourceKey.architecture.rawValue: EMBDevice.architecture
        ]

        addRequiredResources(resourcesMap)
    }
}
