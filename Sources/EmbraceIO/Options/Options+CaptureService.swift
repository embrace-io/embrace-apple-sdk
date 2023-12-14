//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import EmbraceCommon
import Foundation

public extension Array where Element == any CaptureService {
    static var automatic: [any CaptureService] {
        return CaptureServiceFactory.platformCaptureServices
    }
}

public extension Embrace.Options {
    @objc convenience init(
        appId: String,
        appGroupId: String? = nil,
        platform: Platform = .iOS,
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
        platform: Platform = .iOS
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
