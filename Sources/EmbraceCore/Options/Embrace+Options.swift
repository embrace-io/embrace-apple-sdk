//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {

    @objc(EMBOptions)
    /// Class used to setup the Embrace SDK.
    public final class Options: NSObject {
        @objc public let appId: String
        @objc public let appGroupId: String?
        @objc public let platform: Platform
        @objc public let endpoints: Embrace.Endpoints
        @objc public let services: [CaptureService]
        @objc public let logLevel: LogLevel

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
        @objc public init(
            appId: String,
            appGroupId: String? = nil,
            platform: Platform = .default,
            endpoints: Embrace.Endpoints? = nil,
            logLevel: LogLevel = .default,
            captureServices: [CaptureService]
        ) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints ?? .init(appId: appId)
            self.services = captureServices
            self.logLevel = logLevel
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
