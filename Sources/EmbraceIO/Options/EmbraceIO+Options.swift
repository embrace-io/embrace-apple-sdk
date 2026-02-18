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

        /// Default initializer for `EmbraceIO.Options` that requires an `appId`.
        ///
        /// - Parameters:
        ///   - appId: The `appId` of the project, if any.
        ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
        ///   - endpoints: `Embrace.Endpoints` to be used. Defaults to the normal Embrace based endpoints for the given `appId`.
        ///   - captureServices: `EmbraceIO.CaptureServicesOptions` that determines which `CaptureServices` will be installed. Includes the default list of services by default. Refer to `EmbraceIO.CaptureServicesOptionsBuilder` to customize this.
        ///   - crashReporter: The `CrashReporter` to be installed.
        ///   - logLevel: The `LogLevel` to use for console logs.
        ///   - otel: `EmbraceIO.OTelOptions` used to setup the OpenTelemetry SDK through Embrace.
        public class func withAppId(
            _ appId: String?,
            platform: Platform = .default,
            endpoints: Embrace.Endpoints? = nil,
            captureServices: EmbraceIO.CaptureServicesOptions = .default(),
            crashReporter: CrashReporter? = KSCrashReporter(),
            logLevel: LogLevel = .default,
            otel: EmbraceIO.OTelOptions? = nil
        ) -> EmbraceIO.Options {
            return EmbraceIO.Options(
                appId: appId,
                platform: platform,
                endpoints: endpoints,
                captureServices: captureServices,
                crashReporter: crashReporter,
                logLevel: logLevel,
                otel: otel,
                runtimeConfiguration: nil
            )
        }

        /// Default initializer for `EmbraceIO.Options` without using an `appId`.
        /// Note that to use the SDK in this mode, you'll need to define the local configuration by passing an object following
        /// the `EmbraceConfigurable` protocol.
        /// On top of this, you should pass exportes in the `EmbraceIO.OTelOptions` to make sure the generated
        /// data is handled since it will not be uploaded to the Embrace servers.
        ///
        /// - Parameters:
        ///   - localConfiguration: `EmbraceConfigurable` instance.
        ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
        ///   - captureServices: `EmbraceIO.CaptureServicesOptions` that determines which `CaptureServices` will be installed. Includes the default list of services by default. Refer to `EmbraceIO.CaptureServicesOptionsBuilder` to customize this.
        ///   - crashReporter: The `CrashReporter` to be installed.
        ///   - logLevel: The `LogLevel` to use for console logs.
        ///   - otel: `EmbraceIO.OTelOptions` used to setup the OpenTelemetry SDK through Embrace.
        public class func withLocalConfiguration(
            _ localConfiguration: EmbraceConfigurable = .default,
            platform: Platform = .default,
            captureServices: EmbraceIO.CaptureServicesOptions = .default(),
            crashReporter: CrashReporter? = KSCrashReporter(),
            logLevel: LogLevel = .default,
            otel: EmbraceIO.OTelOptions
        ) -> EmbraceIO.Options {
            return EmbraceIO.Options(
                appId: nil,
                platform: platform,
                endpoints: nil,
                captureServices: captureServices,
                crashReporter: crashReporter,
                logLevel: logLevel,
                otel: otel,
                runtimeConfiguration: localConfiguration
            )
        }

        internal init(
            appId: String?,
            platform: Platform,
            endpoints: Embrace.Endpoints?,
            captureServices: EmbraceIO.CaptureServicesOptions,
            crashReporter: CrashReporter?,
            logLevel: LogLevel,
            otel: EmbraceIO.OTelOptions?,
            runtimeConfiguration: EmbraceConfigurable?
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

            // local configuration only available when there's no appId
            if let runtimeConfiguration, appId == nil {
                self.runtimeConfiguration = runtimeConfiguration
            } else {
                self.runtimeConfiguration = nil
            }
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
                //                export: options.otel?.embraceOpenTelemetryExport(),
                //                processors: options.otel?.embraceOpenTelemetryProcessors(),
                backtracer: KSCrashBacktracing(),
                symbolicator: KSCrashBacktracing()
            )
        }

        if let otel = options.otel,
            let config = options.runtimeConfiguration
        {
            return Embrace.Options(
                //                export: otel.embraceOpenTelemetryExport(),
                //                processors: otel.embraceOpenTelemetryProcessors(),
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
