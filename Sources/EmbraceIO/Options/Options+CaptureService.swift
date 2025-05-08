//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCore
import EmbraceCommonInternal
import EmbraceCrash
import EmbraceOTelInternal
#endif

public extension Embrace.Options {

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
    ///   - export: `OpenTelemetryExport` object to export telemetry outside of the Embrace backend.
    @objc convenience init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .default,
        endpoints: Embrace.Endpoints? = nil,
        logLevel: LogLevel = .default,
        export: OpenTelemetryExport? = nil
    ) {
        self.init(
            appId: appId,
            appGroupId: appGroupId,
            platform: platform,
            endpoints: endpoints,
            captureServices: .automatic,
            crashReporter: EmbraceCrashReporter(),
            logLevel: logLevel,
            export: export
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
    @objc convenience init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .default
    ) {
        self.init(
            appId: appId,
            appGroupId: appGroupId,
            platform: platform,
            captureServices: .automatic,
            crashReporter: EmbraceCrashReporter()
        )
    }

    /// Initializer for `Embrace.Options` that does not require an appId.

    /// Use this initializer if you don't want the SDK to send data to Embrace's servers.
    /// You must provide your own `OpenTelemetryExport`
    ///
    /// If you wish to customize which `CaptureServices` and `CrashReporter` are installed, please refer to the `Embrace.Options`
    /// initializer found in the `EmbraceCore` target.
    ///
    /// - Parameters:
    ///   - export: `OpenTelemetryExport` object to export telemetry using OpenTelemetry protocols
    ///   - logLevel: The `LogLevel` to use for console logs.
    @objc convenience init(export: OpenTelemetryExport, logLevel: LogLevel = .default) {
        self.init(
            export: export,
            captureServices: .automatic,
            crashReporter: EmbraceCrashReporter(),
            logLevel: logLevel
        )
    }
}

extension Embrace.Options: ExpressibleByStringLiteral {
    public convenience init(stringLiteral value: String) {
        self.init(appId: value)
    }
}

public extension Array where Element == CaptureService {
    static var automatic: [CaptureService] {
        return CaptureServiceBuilder()
            .addDefaults()
            .build()
    }
}
