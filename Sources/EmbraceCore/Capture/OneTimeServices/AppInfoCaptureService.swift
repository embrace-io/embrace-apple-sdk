//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import OpenTelemetryApi
    import EmbraceObjCUtilsInternal
#endif

class AppInfoCaptureService: ResourceCaptureService {

    /// App resources the backend requires on every payload.
    /// These are not captured by `onStart()`, they are persisted by the SDK during `Embrace.init`
    /// so they are guaranteed to be stored before any other telemetry is.
    static var criticalResources: [String: String] {
        var map: [String: String] = [
            // sdk version
            AppResourceKey.sdkVersion.rawValue: EmbraceMeta.sdkVersion
        ]

        // app version
        if let appVersion = EMBDevice.appVersion {
            map[AppResourceKey.appVersion.rawValue] = appVersion
        }

        return map
    }

    override func onStart() {

        let isPreWarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1" ? "true" : "false"

        //
        // Required Resources
        //
        var resourcesMap: [String: String] = [
            // bundle version
            AppResourceKey.bundleVersion.rawValue: EMBDevice.bundleVersion,

            // environment
            AppResourceKey.environment.rawValue: EMBDevice.environment,

            // environment detail
            AppResourceKey.detailedEnvironment.rawValue: EMBDevice.environmentDetail,

            // framework
            AppResourceKey.framework.rawValue: String(Embrace.client?.options.platform.frameworkId ?? -1),

            // process id
            AppResourceKey.processIdentifier.rawValue: ProcessIdentifier.current.stringValue,

            // pre-warm
            AppResourceKey.processPreWarm.rawValue: isPreWarm
        ]

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
