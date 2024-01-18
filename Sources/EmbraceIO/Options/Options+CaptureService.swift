//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import EmbraceCommon
import Foundation

public extension Embrace.Options {

    /// Convenience initializer for `Embrace.Options` that automatically includes the the default `CaptureServices`.
    /// You can see list of platform service defaults in ``CaptureServiceFactory.platformCaptureServices``.
    ///
    /// If you wish to customize which `CaptureServices` are installed, please refer to the `Embrace.Options`
    /// initializer found in the `EmbraceCore` target.
    ///
    /// - Parameters:
    ///   - appId: The `appId` of the project.
    ///   - appGroupId: The app group identifier used by the app, if any.
    ///   - platform: `Platform` in which the app will run. Defaults to `.iOS`.
    ///   - endpoints: `Embrace.Endpoints` instance.
    @objc convenience init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .default,
        endpoints: Embrace.Endpoints
    ) {
        self.init(
            appId: appId,
            appGroupId: appGroupId,
            platform: platform,
            endpoints: endpoints,
            captureServices: .automatic)
    }

    @objc convenience init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .default
    ) {
        self.init(
            appId: appId,
            appGroupId: appGroupId,
            platform: platform,
            captureServices: .automatic)
    }
}

extension Embrace.Options: ExpressibleByStringLiteral {
    public convenience init(stringLiteral value: String) {
        self.init(appId: value)
    }
}

public extension Array where Element == any CaptureService {
    static var automatic: [any CaptureService] {
        return CaptureServiceFactory.platformCaptureServices
    }
}
