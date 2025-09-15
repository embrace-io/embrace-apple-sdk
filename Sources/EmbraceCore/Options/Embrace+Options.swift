//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
#endif

extension Embrace {

    /// Class used to setup the Embrace SDK.
    @objc(EMBOptions)
    public final class Options: NSObject {
        @objc public let appId: String?
        @objc public let appGroupId: String?
        @objc public let platform: Platform
        @objc public let endpoints: Embrace.Endpoints?
        @objc public let services: [CaptureService]
        @objc public let crashReporter: CrashReporter?
        @objc public let logLevel: LogLevel
        @objc public let export: OpenTelemetryExport?
        @objc public let runtimeConfiguration: EmbraceConfigurable?
        @objc public let processors: [OpenTelemetryProcessor]?
        @objc public let backtracer: Backtracer?
        @objc public let symbolicator: Symbolicator?

        /// Default initializer for `Embrace.Options` that requires an array of `CaptureServices` to be passed.
        ///
        /// If you wish to use the default `CaptureServices`, please refer to the `Embrace.Options`
        /// initializer found in the `EmbraceIO` target.
        ///
        /// - Parameters:
        ///   - appId: The `appId` of the project.
        ///   - appGroupId: The app group identifier used by the app, if any.
        ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
        ///   - endpoints: `Embrace.Endpoints` instance.
        ///   - captureServices: The `CaptureServices` to be installed.
        ///   - crashReporter: The `CrashReporter` to be installed.
        ///   - logLevel: The `LogLevel` to use for console logs.
        ///   - export: `OpenTelemetryExport` object to export telemetry using OpenTelemetry protocols
        ///   - processors: `OpenTelemetryProcessor` objects to do extra processing
        ///   - backtracer: Optional `Backtracer` to capture stack traces. Defaults to the
        ///     built-in mechanism, which is sufficient for most apps.
        ///   - symbolicator: Optional `Symbolicator` to resolve frames into symbols;
        ///     without it, only raw addresses are shown.
        @objc public init(
            appId: String,
            appGroupId: String? = nil,
            platform: Platform = .default,
            endpoints: Embrace.Endpoints? = nil,
            captureServices: [CaptureService],
            crashReporter: CrashReporter?,
            logLevel: LogLevel = .default,
            export: OpenTelemetryExport? = nil,
            processors: [OpenTelemetryProcessor]? = nil,
            backtracer: Backtracer? = nil,
            symbolicator: Symbolicator? = nil
        ) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints ?? .init(appId: appId)
            self.services = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.export = export
            self.runtimeConfiguration = nil
            self.processors = processors
            self.backtracer = backtracer
            self.symbolicator = symbolicator
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
        @objc public init(
            export: OpenTelemetryExport,
            platform: Platform = .default,
            captureServices: [CaptureService],
            crashReporter: CrashReporter?,
            logLevel: LogLevel = .default,
            runtimeConfiguration: EmbraceConfigurable = .default,
            backtracer: Backtracer? = nil,
            symbolicator: Symbolicator? = nil
        ) {
            self.appId = nil
            self.appGroupId = nil
            self.platform = platform
            self.endpoints = nil
            self.services = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.export = export
            self.runtimeConfiguration = runtimeConfiguration
            self.processors = nil
            self.backtracer = backtracer
            self.symbolicator = symbolicator
        }
    }
}

extension Embrace.Options {
    /// Validate Options object to make sure it has not been configured ambiguously
    func validate() throws {
        try validateAppId()
        try validateGroupId()
        try validateOTelExport()
    }

    func validateAppId() throws {
        guard let appId = appId else {
            return
        }

        if appId.count != 5 {
            throw EmbraceSetupError.invalidAppId("`appId` must be 5 characters in length if provided")
        }
    }

    func validateGroupId() throws {
        guard let groupId = appGroupId else {
            return
        }

        if groupId.isEmpty {
            throw EmbraceSetupError.invalidAppGroupId("`appGroupId` must not be empty if provided")
        }
    }

    func validateOTelExport() throws {
        if appId == nil, export == nil {
            throw EmbraceSetupError.invalidOptions("`OpenTelemetryExport` must be provided when not using an `appId`")
        }
    }
}
