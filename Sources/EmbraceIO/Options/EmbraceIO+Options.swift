//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceCrash
    import EmbraceKSCrashBacktraceSupport
#endif

extension EmbraceIO {

    /// Class used to setup the Embrace SDK.
    public final class Options {
        public let appId: String?
        public let platform: Platform
        public let endpoints: Embrace.Endpoints?
        public let captureServices: EmbraceIO.CaptureServicesOptions
        public let crashReporter: CrashReporter?
        public let logLevel: LogLevel
        public let otel: EmbraceIO.OTelOptions?
        public let runtimeConfiguration: EmbraceConfigurable?

        /// Default initializer for `Embrace.Options` that requires an array of `CaptureServices` to be passed.
        ///
        /// If you wish to use the default `CaptureServices`, please refer to the `Embrace.Options`
        /// initializer found in the `EmbraceIO` target.
        ///
        /// - Parameters:
        ///   - appId: The `appId` of the project, if any. Note that if no `appId` is passed you are expected to handle the data export yourself.
        ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
        ///   - endpoints: `Embrace.Endpoints` to be used. Defaults to the normal Embrace based endpoints for the given `appId`.
        ///   - captureServices: `EmbraceIO.CaptureServicesOptions` instance to configure th
        ///   - crashReporter: The `CrashReporter` to be installed.
        ///   - logLevel: The `LogLevel` to use for console logs.
        ///   - otel: `EmbraceIO.OTelOptions` used to setup the OpenTelemetry SDK through Embrace. Note that If no `appId` is passed, you should set up processor/exporters through this property to handle the data yourself.
        public init(
            appId: String?,
            platform: Platform = .default,
            endpoints: Embrace.Endpoints? = nil,
            captureServices: EmbraceIO.CaptureServicesOptions = .init(),
            crashReporter: CrashReporter? = KSCrashReporter(),
            logLevel: LogLevel = .default,
            otel: EmbraceIO.OTelOptions? = nil
        ) {
            self.appId = appId
            self.platform = platform

            if let endpoints {
                self.endpoints = endpoints
            } else if let appId {
                self.endpoints = Embrace.Endpoints(appId: appId)
            } else {
                self.endpoints = nil
            }

            self.captureServices = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.otel = otel
            self.runtimeConfiguration = nil
        }
    }
}

extension Embrace.Options {
    static func from(options: EmbraceIO.Options) -> Embrace.Options? {

        if let appId = options.appId {
            return Embrace.Options(
                appId: appId,
                appGroupId: nil,
                platform: options.platform,
                endpoints: options.endpoints,
                captureServices: options.captureServices.list,
                crashReporter: options.crashReporter,
                logLevel: options.logLevel,
                export: options.otel?.embraceOpenTelemetryExport(),
                processors: options.otel?.embraceOpenTelemetryProcessors(),
                backtracer: KSCrashBacktracing(),
                symbolicator: KSCrashBacktracing()
            )
        }

        if let otel = options.otel,
            let config = options.runtimeConfiguration
        {
            return Embrace.Options(
                export: otel.embraceOpenTelemetryExport(),
                processors: otel.embraceOpenTelemetryProcessors(),
                platform: options.platform,
                captureServices: options.captureServices.list,
                crashReporter: options.crashReporter,
                logLevel: options.logLevel,
                runtimeConfiguration: config,
                backtracer: KSCrashBacktracing(),
                symbolicator: KSCrashBacktracing()
            )
        }

        return nil
    }
}
