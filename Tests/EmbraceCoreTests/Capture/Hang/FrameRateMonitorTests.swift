//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

import TestSupport
import XCTest

@testable import EmbraceCore

final class FrameRateMonitorTests: XCTestCase {

    // MARK: - Test Properties

    private var monitor: FrameRateMonitor!
    private var mockObserver: MockHangObserver!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockObserver = MockHangObserver()
    }

    override func tearDown() {
        monitor = nil
        mockObserver = nil
        super.tearDown()
    }

    /// Creates a monitor and schedules a main-thread block that sleeps long
    /// enough to exceed the threshold, triggering a hang detection.
    private func setupMonitor(
        _ observer: MockHangObserver,
        threshold: TimeInterval = 0.05,
        hangAfter delay: TimeInterval = 0.1,
        hangDuration: TimeInterval = 0.2
    ) {
        monitor = FrameRateMonitor(threshold: threshold)
        monitor.hangObserver = observer
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Thread.sleep(forTimeInterval: hangDuration)
        }
    }

    // MARK: - Test Cases

    func testHangDetection() {
        let hangStartedExpectation = expectation(description: "hangStarted should be called")
        let hangEndedExpectation = expectation(description: "hangEnded should be called")

        mockObserver.onHangStarted = { _, _ in hangStartedExpectation.fulfill() }
        mockObserver.onHangEnded = { _, _ in hangEndedExpectation.fulfill() }

        setupMonitor(mockObserver, threshold: 0.05, hangAfter: 0.1, hangDuration: 0.2)

        wait(for: [hangStartedExpectation, hangEndedExpectation], timeout: .longTimeout)

        XCTAssertTrue(mockObserver.hangStartedCalled)
        XCTAssertTrue(mockObserver.hangEndedCalled)
        XCTAssertGreaterThan(mockObserver.lastHangDuration, 0.1)
    }

    func testHangUpdatedIsNeverCalled() {
        // Option A: detection is retroactive — hangUpdated is never called.
        let hangEndedExpectation = expectation(description: "hangEnded should be called")

        mockObserver.onHangEnded = { _, _ in hangEndedExpectation.fulfill() }

        setupMonitor(mockObserver, threshold: 0.05, hangAfter: 0.1, hangDuration: 0.2)

        wait(for: [hangEndedExpectation], timeout: .longTimeout)

        XCTAssertFalse(mockObserver.hangUpdatedCalled)
    }

    func testNoHangForShortDelays() {
        let hangStartedExpectation = expectation(description: "hangStarted should not be called")
        hangStartedExpectation.isInverted = true

        mockObserver.onHangStarted = { _, _ in hangStartedExpectation.fulfill() }

        // Threshold of 1 second, delay of 10 ms — well below the threshold.
        setupMonitor(mockObserver, threshold: 1.0, hangAfter: 0.01, hangDuration: 0.01)

        wait(for: [hangStartedExpectation], timeout: .shortTimeout)

        XCTAssertFalse(mockObserver.hangStartedCalled)
    }

    func testHangStartedCalledBeforeHangEnded() {
        // Because detection is retroactive, hangStarted and hangEnded are
        // always dispatched in order within the same tick.
        var callOrder: [String] = []
        let hangEndedExpectation = expectation(description: "hangEnded should be called")

        mockObserver.onHangStarted = { _, _ in callOrder.append("started") }
        mockObserver.onHangEnded = { _, _ in
            callOrder.append("ended")
            hangEndedExpectation.fulfill()
        }

        setupMonitor(mockObserver, threshold: 0.05, hangAfter: 0.1, hangDuration: 0.2)

        wait(for: [hangEndedExpectation], timeout: .longTimeout)

        XCTAssertEqual(callOrder, ["started", "ended"])
    }

    func testHangDetectedAfterForegroundReset() {
        // After a foreground notification resets state, the monitor should
        // re-arm on the next tick and continue detecting hangs normally.
        let hangEndedExpectation = expectation(description: "hang should be detected after reset")

        mockObserver.onHangEnded = { _, _ in hangEndedExpectation.fulfill() }

        monitor = FrameRateMonitor(threshold: 0.05)
        monitor.hangObserver = mockObserver

        // Simulate a foreground transition, then schedule a hang far enough
        // in the future to let the monitor re-arm (at least one clean tick).
        NotificationCenter.default.post(
            name: Notification.Name("UIApplicationWillEnterForegroundNotification"),
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Thread.sleep(forTimeInterval: 0.2)
        }

        wait(for: [hangEndedExpectation], timeout: .longTimeout)

        XCTAssertTrue(mockObserver.hangStartedCalled)
        XCTAssertTrue(mockObserver.hangEndedCalled)
    }

    func testDeinitCleanup() {
        // Verify that invalidating the display link on deinit does not crash.
        autoreleasepool {
            let localMonitor = FrameRateMonitor(threshold: 0.1)
            localMonitor.hangObserver = mockObserver
            // localMonitor goes out of scope here, triggering deinit.
        }
    }
}

#endif // !os(watchOS)
