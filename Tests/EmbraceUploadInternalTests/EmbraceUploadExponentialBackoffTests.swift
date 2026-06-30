//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceUploadInternal

class EmbraceUploadExponentialBackoffTests: XCTestCase {

    func test_calculateDelay_doublesEachRetryUntilCapped() {
        let backoff = EmbraceUpload.ExponentialBackoff(baseDelay: 0.25, maxDelay: 32.0)

        // delay doubles starting from baseDelay (retryNumber is 1-based)
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 1), 0.25, accuracy: 0.0001)
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 2), 0.5, accuracy: 0.0001)
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 3), 1.0, accuracy: 0.0001)
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 4), 2.0, accuracy: 0.0001)

        // and is capped at maxDelay once the doubling would exceed it
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 20), 32.0, accuracy: 0.0001)
    }

    func test_calculateDelay_appendsExtraDelay() {
        let backoff = EmbraceUpload.ExponentialBackoff(baseDelay: 0.25, maxDelay: 32.0)

        // extraDelay is added on top of the (capped) exponential delay
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 1, appending: 5), 5.25, accuracy: 0.0001)
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 20, appending: 5), 37.0, accuracy: 0.0001)
    }

    func test_init_clampsMaxDelayToAtLeastBaseDelay() {
        // a maxDelay smaller than baseDelay is clamped up to baseDelay, so the cap never undercuts the first delay
        let backoff = EmbraceUpload.ExponentialBackoff(baseDelay: 10.0, maxDelay: 2.0)

        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 1), 10.0, accuracy: 0.0001)
        XCTAssertEqual(backoff.calculateDelay(forRetryNumber: 5), 10.0, accuracy: 0.0001)
    }
}
