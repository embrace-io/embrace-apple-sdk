//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceOTelInternal

class BatchLimitsTests: XCTestCase {
    struct SimpleEmbraceLoggerConfig: EmbraceLoggerConfig {
        var batchLifetimeInSeconds: Int = 0
        var maximumTimeBetweenLogsInSeconds: Int = 0
        var maximumMessageLength: Int = 0
        var maximumAttributes: Int = 0
        var logAmountLimit: Int = 0
    }

    func test_onInvokingFrom_maxAgeIsLoggerConfigBatchLifetime() {
        let randomNumber = Int.random(in: 0...1000)
        let limits = BatchLimits.from(loggerConfig: SimpleEmbraceLoggerConfig(batchLifetimeInSeconds: randomNumber))
        XCTAssertEqual(limits.maxAge, Double(randomNumber))
    }

    func test_onInvokingFrom_maxLogsPerBatchIsLoggerConfigLogAmountLimit() {
        let randomNumber = Int.random(in: 0...1000)
        let limits = BatchLimits.from(loggerConfig: SimpleEmbraceLoggerConfig(logAmountLimit: randomNumber))
        XCTAssertEqual(limits.maxLogsPerBatch, randomNumber)
    }
}
