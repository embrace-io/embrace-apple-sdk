//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    /// Used to construct the http request headers
    class MetadataOptions {
        public let apiKey: String
        public let userAgent: String
        public let deviceId: String

        public init(apiKey: String, userAgent: String, deviceId: String) {
            self.apiKey = apiKey
            self.userAgent = userAgent
            self.deviceId = deviceId
        }
    }
}
