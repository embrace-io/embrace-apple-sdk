//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

/// The screen-load semantics are a wire contract shared with Android, so every literal is pinned here.
class SpanSemanticsScreenLoadTests: XCTestCase {

    func test_spanNameAndType() {
        XCTAssertEqual(SpanSemantics.ScreenLoad.name, "screen-load")
        XCTAssertEqual(EmbraceType.screenLoad.rawValue, "perf.screen_load")
    }

    func test_attributeKeys() {
        XCTAssertEqual(SpanSemantics.View.keyViewName, "view.name")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyOutcome, "screen_load.outcome")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyNavStartDelayMs, "screen_load.nav_start_delay_ms")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyNavDurationMs, "screen_load.nav_duration_ms")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyFirstFrameDurationMs, "screen_load.first_frame_duration_ms")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyIdleThresholdMs, "screen_load.idle_threshold_ms")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyTimeoutMs, "screen_load.timeout_ms")
        XCTAssertEqual(SpanSemantics.ScreenLoad.keyNavTimeoutMs, "screen_load.nav_timeout_ms")
    }

    func test_outcomeValues() {
        XCTAssertEqual(SpanSemantics.ScreenLoad.outcomeSettled, "settled")
        XCTAssertEqual(SpanSemantics.ScreenLoad.outcomeTimedOut, "timed_out")
        XCTAssertEqual(SpanSemantics.ScreenLoad.outcomeUserInterrupted, "user_interrupted")
        XCTAssertEqual(SpanSemantics.ScreenLoad.outcomeNavigationInterrupted, "navigation_interrupted")
    }
}
