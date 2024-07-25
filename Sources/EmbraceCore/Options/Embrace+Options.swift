//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal

extension Embrace {

    /// Class used to setup the Embrace SDK.
    @objc(EMBOptions)
    public final class Options: NSObject {
        @objc public let appId: String
        @objc public let appGroupId: String?
        @objc public let platform: Platform
        @objc public let endpoints: Embrace.Endpoints
        @objc public let services: [CaptureService]
        @objc public let crashReporter: CrashReporter?
        @objc public let logLevel: LogLevel
        @objc public let export: OpenTelemetryExport?

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
        ///   - export: `OpenTelemetryExport` object to export telemetry outside of the Embrace backend.
        @objc public init(
            appId: String,
            appGroupId: String? = nil,
            platform: Platform = .default,
            endpoints: Embrace.Endpoints? = nil,
            captureServices: [CaptureService],
            crashReporter: CrashReporter?,
            logLevel: LogLevel = .default,
            export: OpenTelemetryExport? = nil
        ) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints ?? .init(appId: appId)
            self.services = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.export = export
        }
    }
}

internal extension Embrace.Options {
    func validateAppId() throws {
        // this also covers if it's empty
        if self.appId.count != 5 {
            throw EmbraceSetupError.invalidAppId("App Id must be 5 characters in length")
        }
    }

    func validateGroupId() throws {
        if let groupId = self.appGroupId {
            if groupId.isEmpty {
                throw EmbraceSetupError.invalidAppGroupId("group id must not be empty if provided")
            }
        }
    }
}
