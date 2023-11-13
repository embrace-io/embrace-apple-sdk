//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {

    @objc(EMBOptions)
    public final class Options: NSObject {
        @objc public let appId: String
        @objc public let appGroupId: String?
        @objc public let platform: Platform
        @objc public let endpoints: Embrace.Endpoints
        @objc public let collectors: [Collector]

        @objc public init(
            appId: String,
            appGroupId: String? = nil,
            platform: Platform = .iOS,
            endpoints: Embrace.Endpoints = .init(),
            collectors: [Collector] = .automatic

        ) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints
            self.collectors = collectors
        }
    }
}

extension Embrace.Options: ExpressibleByStringLiteral {

    public convenience init(stringLiteral value: String) {
        self.init(appId: value)
    }

}
