//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

public extension RemoteConfig {
    struct Options {
        let apiBaseUrl: String
        let queue: DispatchQueue

        let appId: String
        let deviceId: DeviceIdentifier
        let osVersion: String
        let sdkVersion: String
        let appVersion: String
        let userAgent: String

        let urlSessionConfiguration: URLSessionConfiguration

        public init(
            apiBaseUrl: String,
            queue: DispatchQueue,
            appId: String,
            deviceId: DeviceIdentifier,
            osVersion: String,
            sdkVersion: String,
            appVersion: String,
            userAgent: String,
            urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
        ) {
            self.apiBaseUrl = apiBaseUrl
            self.queue = queue
            self.appId = appId
            self.deviceId = deviceId
            self.osVersion = osVersion
            self.sdkVersion = sdkVersion
            self.appVersion = appVersion
            self.userAgent = userAgent
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }
}
