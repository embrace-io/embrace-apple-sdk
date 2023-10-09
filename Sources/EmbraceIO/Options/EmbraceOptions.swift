//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public class EmbraceOptions: NSObject {
    @objc public let appId: String
    @objc public let appGroupId: String?
    @objc public let platform: EmbracePlatform

    @objc public var endpointsConfig: EmbraceEndpoints = EmbraceEndpoints()

    @objc public init?(appId: String, appGroupId: String?, platform: EmbracePlatform) {

        if EmbraceOptions.validateAppId(appId: appId) == false {
            print("Invalid Embrace appId: \(appId)")
            return nil
        }

        self.appId = appId
        self.appGroupId = appGroupId
        self.platform = platform
    }

    private class func validateAppId(appId: String) -> Bool {
        return appId.count == 5
    }
}
