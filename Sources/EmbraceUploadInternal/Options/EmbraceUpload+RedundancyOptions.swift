//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension EmbraceUpload {
    public class RedundancyOptions {
        /// Retry budget per upload operation. -1 means unlimited.
        /// A positive value causes the record to be permanently deleted from cache when exhausted.
        /// Use 0 to disable retries entirely.
        public let automaticRetryCount: Int

        /// Maximum number of upload operations per queue.
        /// When a queue is at capacity, new uploads are cached and picked up later via queue draining.
        public let queueLimit: Int

        /// Enable to automatically try to send any unsent cached data when the phone regains internet connection.
        public let retryOnInternetConnected: Bool

        /// Defines the behavior to use when retrying requests
        public let exponentialBackoffBehavior: ExponentialBackoff

        public init(
            automaticRetryCount: Int = -1,
            queueLimit: Int = 10,
            retryOnInternetConnected: Bool = true,
            exponentialBackoffBehavior: ExponentialBackoff = .init()
        ) {
            self.automaticRetryCount = automaticRetryCount
            self.queueLimit = queueLimit
            self.retryOnInternetConnected = retryOnInternetConnected
            self.exponentialBackoffBehavior = exponentialBackoffBehavior
        }
    }
}
