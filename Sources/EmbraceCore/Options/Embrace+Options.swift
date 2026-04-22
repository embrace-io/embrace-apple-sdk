//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
    import EmbraceSemantics
#endif

extension Embrace {

    /// Internal options used to setup the Embrace SDK. Not part of the public API.
    package struct Options {
        package let appId: String?
        package let appGroupId: String?
        package let platform: EmbracePlatform
        package let endpoints: EmbraceEndpoints?
        package let services: [CaptureService]
        package let crashReporter: CrashReporter?
        package let logLevel: EmbraceLogLevel
        package let runtimeConfiguration: EmbraceConfigurable?
        package let backtracer: Backtracer?
        package let symbolicator: Symbolicator?

        /// Optional OTel signal bridge. When provided, span/log lifecycle events from Core
        /// are forwarded into the OTel SDK pipeline and external OTel signals are fed back into Core.
        package var bridge: EmbraceOTelSignalBridge?

        package init(
            appId: String,
            appGroupId: String? = nil,
            platform: EmbracePlatform = .default,
            endpoints: EmbraceEndpoints? = nil,
            captureServices: [CaptureService],
            crashReporter: CrashReporter?,
            logLevel: EmbraceLogLevel = .default,
            backtracer: Backtracer? = nil,
            symbolicator: Symbolicator? = nil
        ) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints ?? EmbraceEndpoints(appId: appId)
            self.services = captureServices
            self.crashReporter = crashReporter
            self.logLevel = logLevel
            self.runtimeConfiguration = nil
            self.backtracer = backtracer
            self.symbolicator = symbolicator
        }

        package init(
            platform: EmbracePlatform = .default,
            captureServices: [CaptureService],
            crashReporter: CrashReporter?,
            logLevel: EmbraceLogLevel = .default,
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
            self.runtimeConfiguration = runtimeConfiguration
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
}
