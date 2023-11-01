//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Embrace {

    @objc(EMBOptions)
    public class Options: NSObject {
        @objc public let appId: String
        @objc public let appGroupId: String?
        @objc public let platform: Platform
        @objc public let endpoints: Embrace.Endpoints

        @objc public init(appId: String, appGroupId: String? = nil, platform: Platform = .iOS, endpoints: Embrace.Endpoints = .init()) {
            self.appId = appId
            self.appGroupId = appGroupId
            self.platform = platform
            self.endpoints = endpoints
        }
    }
}
