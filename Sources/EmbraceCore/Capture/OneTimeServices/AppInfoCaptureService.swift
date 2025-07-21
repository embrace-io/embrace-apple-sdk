//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import OpenTelemetryApi
    @_implementationOnly import EmbraceObjCUtilsInternal
#endif

class AppInfoCaptureService: ResourceCaptureService {

    override func onStart() {

        let isPreWarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1" ? "true" : "false"

        var resourcesMap: [String: String] = [
            // bundle version
            AppResourceKey.bundleVersion.rawValue: EMBDevice.bundleVersion,

            // environment
            AppResourceKey.environment.rawValue: EMBDevice.environment,

            // environment detail
            AppResourceKey.detailedEnvironment.rawValue: EMBDevice.environmentDetail,

            // framework
            AppResourceKey.framework.rawValue: String(Embrace.client?.options.platform.frameworkId ?? -1),

            // sdk version
            AppResourceKey.sdkVersion.rawValue: EmbraceMeta.sdkVersion,

            // process id
            AppResourceKey.processIdentifier.rawValue: ProcessIdentifier.current.hex,

            // pre-warm
            AppResourceKey.processPreWarm.rawValue: isPreWarm
        ]

        // app version
        if let appVersion = EMBDevice.appVersion {
            resourcesMap[AppResourceKey.appVersion.rawValue] = appVersion
        }

        // build UUID
        if let buildUUID = EMBDevice.buildUUID {
            resourcesMap[AppResourceKey.buildID.rawValue] = buildUUID.withoutHyphen
        }

        // process start time
        if let processStartTime = ProcessMetadata.startTime {
            resourcesMap[AppResourceKey.processStartTime.rawValue] = String(
                processStartTime.nanosecondsSince1970Truncated)
        }

        addRequiredResources(resourcesMap)
    }
}
