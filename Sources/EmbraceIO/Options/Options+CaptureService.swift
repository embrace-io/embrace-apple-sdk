//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCore
    import EmbraceCommonInternal
    import EmbraceCrash
    import EmbraceKSCrashBacktraceSupport
    import EmbraceSemantics
    import KSCrashDemangleFilter
#endif

extension Embrace.Options {

    package init(
        appId: String,
        appGroupId: String? = nil,
        platform: EmbracePlatform = .default,
        endpoints: EmbraceEndpoints? = nil,
        logLevel: EmbraceLogLevel = .default
    ) {
        self.init(
            appId: appId,
            appGroupId: appGroupId,
            platform: platform,
            endpoints: endpoints,
            captureServices: .automatic,
            crashReporter: KSCrashReporter(),
            logLevel: logLevel,
            backtracer: KSCrashBacktracing(),
            symbolicator: KSCrashBacktracing()
        )
    }

    package init(
        appId: String,
        appGroupId: String? = nil,
        platform: EmbracePlatform = .default
    ) {
        self.init(
            appId: appId,
            appGroupId: appGroupId,
            platform: platform,
            captureServices: .automatic,
            crashReporter: KSCrashReporter(),
            backtracer: KSCrashBacktracing(),
            symbolicator: KSCrashBacktracing()
        )
    }
}

extension Array where Element == CaptureService {
    public static var automatic: [CaptureService] {
        return CaptureServiceBuilder()
            .addDefaults()
            .build()
    }
}
