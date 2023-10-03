//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    /// Used to construct the http request headers
    class MetadataOptions {
        public var apiKey: String
        public var userAgent: String
        public var deviceId: String

        public init(apiKey: String, userAgent: String, deviceId: String) {
            self.apiKey = apiKey
            self.userAgent = userAgent
            self.deviceId = deviceId
        }
    }
}
