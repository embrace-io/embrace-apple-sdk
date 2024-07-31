//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceConfig {
    class Options {
        let apiBaseUrl: String
        let queue: DispatchQueue

        let appId: String
        let deviceId: String
        let osVersion: String
        let sdkVersion: String
        let appVersion: String
        let userAgent: String

        let minimumUpdateInterval: TimeInterval
        let urlSessionConfiguration: URLSessionConfiguration

        public init(
            apiBaseUrl: String,
            queue: DispatchQueue,
            appId: String,
            deviceId: String,
            osVersion: String,
            sdkVersion: String,
            appVersion: String,
            userAgent: String,
            minimumUpdateInterval: TimeInterval = 60 * 60,
            urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default) {

            self.apiBaseUrl = apiBaseUrl
            self.queue = queue
            self.appId = appId
            self.deviceId = deviceId
            self.osVersion = osVersion
            self.sdkVersion = sdkVersion
            self.appVersion = appVersion
            self.userAgent = userAgent
            self.minimumUpdateInterval = minimumUpdateInterval
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }
}
