//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class RedundancyOptions {
        /// Total amount of times a request will be immediately retried in case of error. Use 0 to disable.
        public var automaticRetryCount: Int = 0

        /// Enable to automatically try to send any unsent cached data when the phone regains internet connection.
        public var retryOnInternetConnected: Bool = true

        public init(automaticRetryCount: Int = 0, retryOnInternetConnected: Bool = true) {
            self.automaticRetryCount = automaticRetryCount
            self.retryOnInternetConnected = retryOnInternetConnected
        }
    }
}
