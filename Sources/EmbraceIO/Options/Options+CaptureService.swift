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
    import KSCrashDemangleFilter
#endif

extension Embrace.Options {

    /// Convenience initializer for `Embrace.Options` that automatically includes the default `CaptureServices` and `CrashReporter`,
    /// You can see list of platform service defaults in ``CaptureServiceBuilder.addDefaults``.
    ///
    /// If you wish to customize which `CaptureServices` and `CrashReporter` are installed, please refer to the `Embrace.Options`
    /// initializer found in the `EmbraceCore` target.
    ///
    /// - Parameters:
    ///   - appId: The `appId` of the project.
    ///   - appGroupId: The app group identifier used by the app, if any.
    ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
    ///   - endpoints: `Embrace.Endpoints` instance.
    ///   - logLevel: `LogLevel` for Embrace console logs
    public init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .default,
        endpoints: Embrace.Endpoints? = nil,
        logLevel: LogLevel = .default
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

    /// Convenience initializer for `Embrace.Options` that automatically includes the default `CaptureServices` and `CrashReporter`,
    /// You can see list of platform service defaults in ``CaptureServiceBuilder.addDefaults``.
    ///
    /// If you wish to customize which `CaptureServices` and `CrashReporter` are installed, please refer to the `Embrace.Options`
    /// initializer found in the `EmbraceCore` target.
    ///
    /// - Parameters:
    ///   - appId: The `appId` of the project.
    ///   - appGroupId: The app group identifier used by the app, if any.
    ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
    public init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .default
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
