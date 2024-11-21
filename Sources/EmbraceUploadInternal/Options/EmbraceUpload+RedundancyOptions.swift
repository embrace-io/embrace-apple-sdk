//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class RedundancyOptions {
        /// Total amount of times a request could be retried.
        public var maximumAmountOfRetries: Int

        /// Enable to automatically try to send any unsent cached data when the phone regains internet connection.
        public var retryOnInternetConnected: Bool

        /// Defines the behavior to use when retrying requests
        public var exponentialBackoffBehavior: ExponentialBackoff

        public init(
            maximumAmountOfRetries: Int = 20,
            retryOnInternetConnected: Bool = true,
            exponentialBackoffBehavior: ExponentialBackoff = .init()
        ) {
            self.maximumAmountOfRetries = maximumAmountOfRetries
            self.retryOnInternetConnected = retryOnInternetConnected
            self.exponentialBackoffBehavior = exponentialBackoffBehavior
        }
    }
}
