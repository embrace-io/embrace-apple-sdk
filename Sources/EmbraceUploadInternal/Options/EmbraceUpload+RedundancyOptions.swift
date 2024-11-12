//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    class RedundancyOptions {
        /// Total amount of times a request will be immediately retried in case of error. Use 0 to disable.
        public var automaticRetryCount: Int

        /// Enable to automatically try to send any unsent cached data when the phone regains internet connection.
        public var retryOnInternetConnected: Bool

        /// Defines the behavior to use when retrying requests
        public var exponentialBackoffBehavior: ExponentialBackoff

        public init(
            automaticRetryCount: Int = 3,
            retryOnInternetConnected: Bool = true,
            exponentialBackoffBehavior: ExponentialBackoff = .init()
        ) {
            self.automaticRetryCount = automaticRetryCount
            self.retryOnInternetConnected = retryOnInternetConnected
            self.exponentialBackoffBehavior = exponentialBackoffBehavior
        }
    }
}

public extension EmbraceUpload {
    struct ExponentialBackoff {
        let baseDelay: Double
        let maxDelay: Double
        let exponentialFactor: Double

        public init(
            baseDelay: Double = 1.0,
            maxDelay: Double = 60.0,
            exponentialFactor: Double = 2.0
        ) {
            self.baseDelay = baseDelay
            self.maxDelay = max(maxDelay, baseDelay) // prevent somebody from adding a baseDelay larger than the maxDelay
            self.exponentialFactor = exponentialFactor
        }

        /// Calculates the exponential backoff delay based on the given `retryNumber`.
        ///
        /// This function computes the delay for a retry attempt using an exponential backoff algorithm,
        /// which gradually increases the delay between retries based on a base delay and an exponential factor.
        /// The computed delay is capped by a maximum value to prevent excessive waiting times.
        ///
        /// ### Example:
        /// Given an `ExponentialBackoff` with:
        /// - `baseDelay = 1.0 seconds`
        /// - `exponentialFactor = 2.0`
        /// - `maxDelay = 60.0 seconds`
        ///
        /// For the first retry, the delay would be: `1.0 * 2^1 = 2.0 seconds`.
        ///
        /// For the second retry, the delay would be:`1.0 * 2^2 = 4.0 seconds`.
        ///
        /// For subsequent retries, the delay increases exponentially, but will not exceed `maxDelay`.
        ///
        /// - Parameter retryCount: The current number of retries remaining.
        /// - Returns: An interger representing the calculated delay before the next retry attempt.
        func calculateDelay(forRetryNumber retryNumber: Int) -> Int {
            return Int(min(baseDelay * pow(exponentialFactor, Double(retryNumber)), maxDelay))
        }
    }
}
