//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension EmbraceUpload {
    public struct ExponentialBackoff {
        let baseDelay: Double
        let maxDelay: Double

        public init(
            baseDelay: Double = 0.25,
            maxDelay: Double = 32.0
        ) {
            self.baseDelay = baseDelay

            // prevent somebody from adding a baseDelay larger than the maxDelay
            self.maxDelay = max(maxDelay, baseDelay)
        }

        /// Calculates the exponential backoff delay based on the given `retryNumber`.
        ///
        /// This function computes the delay for a retry attempt using an exponential backoff algorithm.
        /// The delay doubles with each retry, starting from `baseDelay`.
        /// The computed delay is capped by `maxDelay` to prevent excessive waiting times.
        ///
        /// ### Example:
        /// Given an `ExponentialBackoff` with:
        /// - `baseDelay = 0.25 seconds`
        /// - `maxDelay = 32.0 seconds`
        ///
        /// For the first retry (retryNumber = 1), the delay would be: `0.25 * pow(2, 0) = 0.25 seconds`.
        /// For the second retry (retryNumber = 2), the delay would be: `0.25 * pow(2, 1) = 0.5 seconds`.
        ///
        /// For subsequent retries, the delay continues to double, but will be capped at `maxDelay`.
        ///
        /// - Parameters:
        ///    - retryNumber: The current retry attempt number (1-based).
        ///    - extraDelay: An optional amount of delay (in seconds) appended to the final calculation. Default is 0.
        /// - Returns: The calculated delay (in seconds) before the next retry attempt.
        func calculateDelay(forRetryNumber retryNumber: Int, appending extraDelay: TimeInterval = 0) -> TimeInterval {
            return min(baseDelay * pow(2.0, Double(retryNumber - 1)), maxDelay) + extraDelay
        }
    }
}
