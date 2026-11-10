//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

final class SlowCallbackRecorderTests: XCTestCase {

    private let countKey = "emb.private.slow_callback.network_span_parent_provider.count"
    private let maxMsKey = "emb.private.slow_callback.network_span_parent_provider.max_ms"

    private var sessionSpan: MockSpan?
    private var sut: SlowCallbackRecorder!

    override func setUpWithError() throws {
        sessionSpan = MockSpan(name: "emb-session")
        sut = SlowCallbackRecorder { [unowned self] in self.sessionSpan }
    }

    private func record(_ duration: TimeInterval, callback: SlowCallback = .networkSpanParentProvider) {
        sut.recordSlowCall(callback, duration: duration)
    }

    private func attribute(_ key: String, on span: MockSpan? = nil) -> String? {
        return (span ?? sessionSpan)?.attributes[key]?.description
    }

    func test_keys_matchTheSharedNames() {
        XCTAssertEqual(SlowCallback.networkSpanParentProvider.countKey, countKey)
        XCTAssertEqual(SlowCallback.networkSpanParentProvider.maxMsKey, maxMsKey)
    }

    func test_noSlowCalls_setsNoAttributes() {
        XCTAssertNil(attribute(countKey))
        XCTAssertNil(attribute(maxMsKey))
    }

    func test_everyCall_updatesTheCountAndTheLongestCall() {
        record(0.012)
        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "12")

        record(0.030)
        XCTAssertEqual(attribute(countKey), "2")
        XCTAssertEqual(attribute(maxMsKey), "30")

        record(0.007)
        XCTAssertEqual(attribute(countKey), "3")
        XCTAssertEqual(attribute(maxMsKey), "30")
    }

    func test_values_areStrings() {
        record(0.012)
        XCTAssertTrue(sessionSpan?.attributes[countKey] is String)
        XCTAssertTrue(sessionSpan?.attributes[maxMsKey] is String)
    }

    func test_longestCall_isRoundedDownToWholeMilliseconds() {
        record(0.0059)
        XCTAssertEqual(attribute(maxMsKey), "5")
    }

    func test_newSessionPart_startsOver() {
        record(0.030)
        record(0.030)
        let previousSpan = sessionSpan

        sessionSpan = MockSpan(name: "emb-session")
        record(0.010)

        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "10")
        XCTAssertEqual(attribute(countKey, on: previousSpan), "2")
        XCTAssertEqual(attribute(maxMsKey, on: previousSpan), "30")
    }

    func test_noSessionPart_dropsTheCall() {
        sessionSpan = nil
        record(0.030)

        sessionSpan = MockSpan(name: "emb-session")
        record(0.010)

        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "10")
    }

    func test_callbacks_areCountedSeparately() {
        let otherCallback = SlowCallback(
            countKey: "emb.private.slow_callback.other_callback.count",
            maxMsKey: "emb.private.slow_callback.other_callback.max_ms"
        )
        record(0.030, callback: otherCallback)
        record(0.010)

        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "10")
        XCTAssertEqual(attribute("emb.private.slow_callback.other_callback.count"), "1")
        XCTAssertEqual(attribute("emb.private.slow_callback.other_callback.max_ms"), "30")
    }

    func test_concurrentCalls_areAllCounted() {
        // `MockSpan` isn't thread safe, so the span written to here is only read once every call has returned.
        let iterations = 1000
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            record(TimeInterval(index) / 1000)
        }

        XCTAssertEqual(attribute(countKey), String(iterations))
        XCTAssertEqual(attribute(maxMsKey), String(iterations - 1))
    }
}
