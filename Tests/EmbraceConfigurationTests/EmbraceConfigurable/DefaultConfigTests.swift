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
        XCTAssertTrue(config.isMetricKitEnabled)
        XCTAssertTrue(config.isMetricKitCrashCaptureEnabled)
        XCTAssertEqual(config.metricKitCrashSignals, ["SIGKILL"])
        XCTAssertFalse(config.isMetricKitHangCaptureEnabled)
        XCTAssertEqual(config.spanEventsLimits, SpanEventsLimits())
        XCTAssertEqual(config.logsLimits, LogsLimits())
        XCTAssertEqual(config.internalLogLimits, InternalLogLimits())
        XCTAssertTrue(config.networkPayloadCaptureRules.isEmpty)
    }
}
