import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal

final class HangWatchdogTests: XCTestCase {

    // MARK: - Test Properties

    private var watchdog: HangWatchdog!
    private var mockObserver: MockHangObserver!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockObserver = MockHangObserver()
    }

    override func tearDown() {
        watchdog = nil
        mockObserver = nil
        super.tearDown()
    }

    private func setupWatchdog(_ observer: MockHangObserver, threshold: TimeInterval = 0.249, hang: TimeInterval = 1) {
        watchdog = HangWatchdog(threshold: threshold, runLoop: RunLoop.main)
        watchdog.hangObserver = observer
        DispatchQueue.main.asyncAfter(deadline: .now() + hang) {
            // Block thread long enough to trigger multiple updates
            Thread.sleep(forTimeInterval: hang)
        }
    }

    // MARK: - Test Cases

    func testInitialization() {
        // Test that the watchdog initializes with default parameters
        watchdog = HangWatchdog()
        XCTAssertEqual(watchdog.threshold, HangWatchdog.defaultAppleHangThreshold)
        XCTAssertNil(watchdog.hangObserver)

        // Test custom threshold
        let customThreshold: TimeInterval = 0.5
        watchdog = HangWatchdog(threshold: customThreshold)
        XCTAssertEqual(watchdog.threshold, customThreshold)
    }

    func testObserverAssignment() {
        // Test that observer can be assigned
        watchdog = HangWatchdog()
        watchdog.hangObserver = mockObserver
        XCTAssertTrue(watchdog.hangObserver === mockObserver)
    }

    func testHangDetection() {
        // Create expectation for hang detection
        let hangExpectation = expectation(description: "Hang should be detected")

        // Set up observer with callback
        mockObserver.onHangStarted = { _, _ in
            hangExpectation.fulfill()
        }

        // Create watchdog with a short threashold
        // and hand the main queue
        setupWatchdog(mockObserver, threshold: 0.05, hang: 0.2)

        // Wait for expectation with timeout
        wait(for: [hangExpectation], timeout: .longTimeout)

        // Verify hang was detected
        XCTAssertTrue(mockObserver.hangStartedCalled)
        XCTAssertGreaterThan(mockObserver.lastHangDuration, UInt64(0.1 * 1_000_000_000))
    }

    func testHangUpdates() {
        // Create expectations
        let hangStartedExpectation = expectation(description: "Hang should start")
        let hangUpdatedExpectation = expectation(description: "Hang should be updated")

        // Set up observer with callbacks
        mockObserver.onHangStarted = { _, _ in
            hangStartedExpectation.fulfill()
        }

        mockObserver.onHangUpdated = { _, _ in
            hangUpdatedExpectation.fulfill()
            self.watchdog.hangObserver = nil
        }

        // Create watchdog with a short threashold
        // and hand the main queue
        setupWatchdog(mockObserver, threshold: 0.05, hang: 0.2)

        // Wait for expectations
        wait(for: [hangStartedExpectation, hangUpdatedExpectation], timeout: .longTimeout)

        // Verify hang was updated
        XCTAssertTrue(mockObserver.hangStartedCalled)
        XCTAssertTrue(mockObserver.hangUpdatedCalled)
    }

    func testHangEnd() {
        // Create expectations
        let hangEndedExpectation = expectation(description: "Hang should end")

        // Set up observer
        mockObserver.onHangEnded = { _, _ in
            hangEndedExpectation.fulfill()
        }

        // Create watchdog with a short threashold
        // and hand the main queue
        setupWatchdog(mockObserver, threshold: 0.05, hang: 0.1)

        // Wait for hang to end
        wait(for: [hangEndedExpectation], timeout: .longTimeout)

        // Verify hang ended was called
        XCTAssertTrue(mockObserver.hangEndedCalled)
    }

    func testNoHangForShortDelays() {
        // Set up observer
        let hangStartedExpectation = expectation(description: "Hang should not be detected")
        hangStartedExpectation.isInverted = true  // We expect this NOT to be fulfilled

        mockObserver.onHangStarted = { _, _ in
            hangStartedExpectation.fulfill()
        }

        // Create watchdog with a short threashold
        // and hand the main queue
        setupWatchdog(mockObserver, threshold: 1, hang: 0.01)

        // Wait briefly to ensure no hang is detected
        wait(for: [hangStartedExpectation], timeout: .shortTimeout)

        // Verify no hang was detected
        XCTAssertFalse(mockObserver.hangStartedCalled)
    }

    func testDeinitCleanup() {
        // Create and destroy watchdog to test cleanup
        autoreleasepool {
            let localWatchdog = HangWatchdog(threshold: 0.1)
            localWatchdog.hangObserver = mockObserver
            // Let watchdog go out of scope
        }

        // No assertions needed - we're testing that deinit doesn't crash
    }
}

// MARK: - Test Helpers

class MockHangObserver: HangObserver {

    // Callback handlers
    var onHangStarted: ((UInt64, UInt64) -> Void)?
    var onHangUpdated: ((UInt64, UInt64) -> Void)?
    var onHangEnded: ((UInt64, UInt64) -> Void)?

    // Tracking properties
    var hangStartedCalled = false
    var hangUpdatedCalled = false
    var hangEndedCalled = false

    var hangStartedCallCount = 0
    var hangUpdatedCallCount = 0
    var hangEndedCallCount = 0

    var lastStartTime: UInt64 = 0
    var lastUpdateTime: UInt64 = 0
    var lastEndTime: UInt64 = 0
    var lastHangDuration: UInt64 = 0

    func hangStarted(at: NanosecondClock, duration: NanosecondClock) {
        hangStartedCalled = true
        hangStartedCallCount += 1
        lastStartTime = at.monotonic
        lastHangDuration = duration.monotonic
        onHangStarted?(at.monotonic, duration.monotonic)
    }

    func hangUpdated(at: NanosecondClock, duration: NanosecondClock) {
        hangUpdatedCalled = true
        hangUpdatedCallCount += 1
        lastUpdateTime = at.monotonic
        lastHangDuration = duration.monotonic
        onHangUpdated?(at.monotonic, duration.monotonic)
    }

    func hangEnded(at: EmbraceCore.NanosecondClock, duration: EmbraceCore.NanosecondClock) {
        hangEndedCalled = true
        hangEndedCallCount += 1
        lastEndTime = at.monotonic
        lastHangDuration = duration.monotonic
        onHangEnded?(at.monotonic, duration.monotonic)
    }
}
