//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension RemoteConfig {
    public struct Options {
        let apiBaseUrl: String
        let queue: DispatchQueue

        let appId: String
        let deviceId: EmbraceIdentifier
        let osVersion: String
        let sdkVersion: String
        let appVersion: String
        let userAgent: String

        let cacheLocation: URL?

        let urlSessionConfiguration: URLSessionConfiguration

        public init(
            apiBaseUrl: String,
            queue: DispatchQueue,
            appId: String,
            deviceId: EmbraceIdentifier,
            osVersion: String,
            sdkVersion: String,
            appVersion: String,
            userAgent: String,
            cacheLocation: URL?,
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
            self.cacheLocation = cacheLocation
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }
}
