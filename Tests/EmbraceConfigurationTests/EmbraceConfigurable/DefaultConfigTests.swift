//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceConfiguration

final class DefaultConfigTests: XCTestCase {

    func test_defaultConfig_hasCorrectValues() {
        let config = DefaultConfig()

        XCTAssertTrue(config.isSDKEnabled)
        XCTAssertFalse(config.isBackgroundSessionEnabled)
        XCTAssertFalse(config.isNetworkSpansForwardingEnabled)
        XCTAssertEqual(config.internalLogLimits, InternalLogLimits())
        XCTAssertTrue(config.networkPayloadCaptureRules.isEmpty)
        XCTAssertTrue(config.isMetricKitEnabled)
    }
}
