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
    private var scheduled: [(delay: TimeInterval, block: () -> Void)] = []
    private var sut: SlowCallbackRecorder!

    override func setUpWithError() throws {
        sessionSpan = MockSpan(name: "emb-session")
        scheduled = []
        sut = SlowCallbackRecorder(
            currentSessionSpan: { [unowned self] in self.sessionSpan },
            schedule: { [unowned self] delay, block in self.scheduled.append((delay, block)) }
        )
    }

    private func record(_ duration: TimeInterval, callback: SlowCallback = .networkSpanParentProvider) {
        sut.recordSlowCall(callback, duration: duration)
    }

    private func fireScheduledFlushes() {
        let blocks = scheduled.map(\.block)
        scheduled = []
        blocks.forEach { $0() }
    }

    private func attribute(_ key: String, on span: MockSpan? = nil) -> String? {
        return (span ?? sessionSpan)?.attributes[key]?.description
    }

    func test_keys_matchTheSharedNames() {
        XCTAssertEqual(SlowCallback.networkSpanParentProvider.countKey, countKey)
        XCTAssertEqual(SlowCallback.networkSpanParentProvider.maxMsKey, maxMsKey)
    }

    func test_noSlowCalls_setsNoAttributes() {
        sut.flush()
        fireScheduledFlushes()
        XCTAssertNil(attribute(countKey))
        XCTAssertNil(attribute(maxMsKey))
    }

    // MARK: - Values

    func test_values_areTheCountAndTheLongestCall() {
        record(0.012)
        sut.flush()
        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "12")

        record(0.030)
        record(0.007)
        sut.flush()
        XCTAssertEqual(attribute(countKey), "3")
        XCTAssertEqual(attribute(maxMsKey), "30")
    }

    func test_values_areStrings() {
        record(0.012)
        sut.flush()
        XCTAssertTrue(sessionSpan?.attributes[countKey] is String)
        XCTAssertTrue(sessionSpan?.attributes[maxMsKey] is String)
    }

    func test_longestCall_isRoundedDownToWholeMilliseconds() {
        record(0.0059)
        sut.flush()
        XCTAssertEqual(attribute(maxMsKey), "5")
    }

    // MARK: - Writes

    func test_fewerCallsThanTheFlushCount_areWrittenWhenTheTimerFires() {
        for _ in 1..<SlowCallbackRecorder.flushCallCount {
            record(0.010)
        }
        XCTAssertNil(attribute(countKey))

        XCTAssertEqual(scheduled.map(\.delay), [SlowCallbackRecorder.flushInterval])
        fireScheduledFlushes()
        XCTAssertEqual(attribute(countKey), String(SlowCallbackRecorder.flushCallCount - 1))
    }

    func test_reachingTheFlushCount_writesRightAway() {
        for _ in 1..<SlowCallbackRecorder.flushCallCount {
            record(0.010)
        }
        XCTAssertNil(attribute(countKey))

        record(0.020)
        XCTAssertEqual(attribute(countKey), String(SlowCallbackRecorder.flushCallCount))
        XCTAssertEqual(attribute(maxMsKey), "20")
    }

    func test_timer_isScheduledOnceUntilItFires() {
        record(0.010)
        record(0.010)
        XCTAssertEqual(scheduled.count, 1)

        fireScheduledFlushes()
        record(0.010)
        XCTAssertEqual(scheduled.count, 1)
        fireScheduledFlushes()
        XCTAssertEqual(attribute(countKey), "3")
    }

    func test_timerFiringWithNothingPending_writesNothing() {
        for _ in 0..<SlowCallbackRecorder.flushCallCount {
            record(0.010)
        }
        sessionSpan?.attributes = [:]

        fireScheduledFlushes()
        XCTAssertNil(attribute(countKey))
    }

    // MARK: - Session parts

    func test_newSessionPart_startsOver() {
        record(0.030)
        record(0.030)
        sut.flush()
        let previousSpan = sessionSpan

        sessionSpan = MockSpan(name: "emb-session")
        record(0.010)
        sut.flush()

        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "10")
        XCTAssertEqual(attribute(countKey, on: previousSpan), "2")
        XCTAssertEqual(attribute(maxMsKey, on: previousSpan), "30")
    }

    func test_newSessionPart_keepsTheScheduledTimer() {
        record(0.010)
        sessionSpan = MockSpan(name: "emb-session")
        record(0.010)

        XCTAssertEqual(scheduled.count, 1)
        fireScheduledFlushes()
        XCTAssertEqual(attribute(countKey), "1")
    }

    func test_noSessionPart_dropsTheCall() {
        sessionSpan = nil
        record(0.030)

        sessionSpan = MockSpan(name: "emb-session")
        record(0.010)
        sut.flush()

        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "10")
    }

    // MARK: - Callbacks

    func test_callbacks_areCountedSeparately() {
        let otherCallback = SlowCallback(
            countKey: "emb.private.slow_callback.other_callback.count",
            maxMsKey: "emb.private.slow_callback.other_callback.max_ms"
        )
        record(0.030, callback: otherCallback)
        record(0.010)
        sut.flush()

        XCTAssertEqual(attribute(countKey), "1")
        XCTAssertEqual(attribute(maxMsKey), "10")
        XCTAssertEqual(attribute("emb.private.slow_callback.other_callback.count"), "1")
        XCTAssertEqual(attribute("emb.private.slow_callback.other_callback.max_ms"), "30")
    }

    func test_concurrentCalls_areAllCounted() {
        // `MockSpan` isn't thread safe, so the span written to here is only read once every call has returned.
        let iterations = 1000
        sut = SlowCallbackRecorder(currentSessionSpan: { [unowned self] in self.sessionSpan }, schedule: { _, _ in })
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            record(TimeInterval(index) / 1000)
        }
        sut.flush()

        XCTAssertEqual(attribute(countKey), String(iterations))
        XCTAssertEqual(attribute(maxMsKey), String(iterations - 1))
    }
}
