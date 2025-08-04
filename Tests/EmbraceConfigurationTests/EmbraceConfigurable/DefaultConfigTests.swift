//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import XCTest

final class DefaultConfigTests: XCTestCase {

    func test_defaultConfig_hasCorrectValues() {
        let config = DefaultConfig()

        XCTAssertTrue(config.isSDKEnabled)
        XCTAssertFalse(config.isBackgroundSessionEnabled)
        XCTAssertFalse(config.isNetworkSpansForwardingEnabled)
        XCTAssertTrue(config.isUiLoadInstrumentationEnabled)
        XCTAssertTrue(config.viewControllerClassNameBlocklist.isEmpty)
        XCTAssertFalse(config.uiInstrumentationCaptureHostingControllers)
        XCTAssertTrue(config.isSwiftUiViewInstrumentationEnabled)
        XCTAssertFalse(config.isMetricKitEnabled)
        XCTAssertFalse(config.isMetricKitCrashCaptureEnabled)
        XCTAssertEqual(config.metricKitCrashSignals, [])
        XCTAssertFalse(config.isMetricKitHangCaptureEnabled)
        XCTAssertEqual(config.spanEventsLimits, SpanEventsLimits())
        XCTAssertEqual(config.logsLimits, LogsLimits())
        XCTAssertEqual(config.internalLogLimits, InternalLogLimits())
        XCTAssertTrue(config.networkPayloadCaptureRules.isEmpty)
    }
}
