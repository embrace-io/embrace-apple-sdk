//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceCrash
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
        public let export: OpenTelemetryExport?
        public let runtimeConfiguration: EmbraceConfigurable?
        public let processors: [OpenTelemetryProcessor]?

        /// Default initializer for `Embrace.Options` that requires an array of `CaptureServices` to be passed.
        ///
        /// If you wish to use the default `CaptureServices`, please refer to the `Embrace.Options`
        /// initializer found in the `EmbraceIO` target.
        ///
        /// - Parameters:
        ///   - appId: The `appId` of the project.
        ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
        ///   - endpoints: `Embrace.Endpoints` to be used. Defaults to the normal Embrace based endpoints for the given `appId`.
        ///   - captureServices: `EmbraceIO.CaptureServicesOptions` instance to configure th
        ///   - crashReporter: The `CrashReporter` to be installed.
        ///   - logLevel: The `LogLevel` to use for console logs.
        ///   - export: `OpenTelemetryExport` object to export telemetry using OpenTelemetry protocols
        ///   - processors: `OpenTelemetryProcessor` objects to do extra processing
        public init(
            appId: String,
            platform: Platform = .default,
            endpoints: Embrace.Endpoints? = nil,
            captureServices: EmbraceIO.CaptureServicesOptions = .init(),
            crashReporter: CrashReporter? = KSCrashReporter(),
            logLevel: LogLevel = .default,
            export: OpenTelemetryExport? = nil,
            processors: [OpenTelemetryProcessor]? = nil
        ) {
            self.appId = appId
            self.platform = platform
            self.endpoints = endpoints ?? Embrace.Endpoints(appId: appId)
            self.captureServices = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.export = export
            self.runtimeConfiguration = nil
            self.processors = processors
        }

        /// Initializer for `Embrace.Options` that does not require an appId.
        /// Use this initializer if you don't want the SDK to send data to Embrace's servers.
        /// You must provide your own `OpenTelemetryExport`
        ///
        /// - Parameters:
        ///   - export: `OpenTelemetryExport` object to export telemetry using OpenTelemetry protocols
        ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
        ///   - captureServices: The `CaptureServices` to be installed.
        ///   - crashReporter: The `CrashReporter` to be installed.
        ///   - logLevel: The `LogLevel` to use for console logs.
        ///   - runtimeConfiguration: An object to control runtime behavior of the SDK itself.
        public init(
            export: OpenTelemetryExport,
            platform: Platform = .default,
            captureServices: EmbraceIO.CaptureServicesOptions = .init(),
            crashReporter: CrashReporter? = KSCrashReporter(),
            logLevel: LogLevel = .default,
            runtimeConfiguration: EmbraceConfigurable = .default
        ) {
            self.appId = nil
            self.platform = platform
            self.endpoints = nil
            self.captureServices = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.export = export
            self.runtimeConfiguration = runtimeConfiguration
            self.processors = nil
        }
    }
}
