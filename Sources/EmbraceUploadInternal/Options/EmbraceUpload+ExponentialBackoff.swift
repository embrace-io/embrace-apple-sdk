//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension EmbraceUpload {
    struct ExponentialBackoff {
        let baseDelay: Double
        let maxDelay: Double

        public init(
            baseDelay: Double = 2.0,
            maxDelay: Double = 32.0
        ) {
            self.baseDelay = baseDelay

            // prevent somebody from adding a baseDelay larger than the maxDelay
            self.maxDelay = max(maxDelay, baseDelay)
        }

        /// Calculates the exponential backoff delay based on the given `retryNumber`.
        ///
        /// This function computes the delay for a retry attempt using an exponential backoff algorithm,
        /// where the delay increases exponentially with each retry, using the `baseDelay` as the base factor.
        /// The computed delay is capped by `maxDelay` to prevent excessive waiting times.
        ///
        /// ### Example:
        /// Given an `ExponentialBackoff` with:
        /// - `baseDelay = 2.0 seconds`
        /// - `maxDelay = 60.0 seconds`
        ///
        /// For the first retry (retryNumber = 1), the delay would be: `pow(2.0, 1) = 2.0 seconds`.
        /// For the second retry (retryNumber = 2), the delay would be: `pow(2.0, 2) = 4.0 seconds`.
        ///
        /// For subsequent retries, the delay continues to grow exponentially, but will be capped at `maxDelay`.
        ///
        /// - Parameters:
        ///    - retryNumber: The current retry attempt number (1-based).
        ///    - extraDelay: An optional amount of delay that could appended to the final calculation. Default is 0.
        /// - Returns: An integer representing the calculated delay (in seconds) before the next retry attempt.
        func calculateDelay(forRetryNumber retryNumber: Int, appending extraDelay: Int = 0) -> Int {
            return Int(min(pow(baseDelay, Double(retryNumber)), maxDelay)) + extraDelay
        }
    }
}
