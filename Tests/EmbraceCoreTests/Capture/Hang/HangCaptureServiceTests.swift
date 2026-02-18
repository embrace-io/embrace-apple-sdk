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
        hangUpdatedExpectation.assertForOverFulfill = false  // Allow multiple updates

        // Set up observer with callbacks
        mockObserver.onHangStarted = { _, _ in
            hangStartedExpectation.fulfill()
        }

        mockObserver.onHangUpdated = { _, _ in
            hangUpdatedExpectation.fulfill()
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
    private let lock = NSLock()

    // Callback handlers
    private var _onHangStarted: ((UInt64, UInt64) -> Void)?
    var onHangStarted: ((UInt64, UInt64) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onHangStarted
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onHangStarted = newValue
        }
    }

    private var _onHangUpdated: ((UInt64, UInt64) -> Void)?
    var onHangUpdated: ((UInt64, UInt64) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onHangUpdated
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onHangUpdated = newValue
        }
    }

    private var _onHangEnded: ((UInt64, UInt64) -> Void)?
    var onHangEnded: ((UInt64, UInt64) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onHangEnded
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onHangEnded = newValue
        }
    }

    // Tracking properties
    private var _hangStartedCalled = false
    var hangStartedCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hangStartedCalled
    }

    private var _hangUpdatedCalled = false
    var hangUpdatedCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hangUpdatedCalled
    }

    private var _hangEndedCalled = false
    var hangEndedCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hangEndedCalled
    }

    private var _hangStartedCallCount = 0
    var hangStartedCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _hangStartedCallCount
    }

    private var _hangUpdatedCallCount = 0
    var hangUpdatedCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _hangUpdatedCallCount
    }

    private var _hangEndedCallCount = 0
    var hangEndedCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _hangEndedCallCount
    }

    private var _lastStartTime: UInt64 = 0
    var lastStartTime: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return _lastStartTime
    }

    private var _lastUpdateTime: UInt64 = 0
    var lastUpdateTime: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return _lastUpdateTime
    }

    private var _lastEndTime: UInt64 = 0
    var lastEndTime: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return _lastEndTime
    }

    private var _lastHangDuration: UInt64 = 0
    var lastHangDuration: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return _lastHangDuration
    }

    func hangStarted(at: EmbraceClock, duration: EmbraceClock) {
        lock.lock()
        _hangStartedCalled = true
        _hangStartedCallCount += 1
        _lastStartTime = at.monotonic.nanosecondsValue
        _lastHangDuration = duration.monotonic.nanosecondsValue
        let callback = _onHangStarted
        lock.unlock()

        callback?(at.monotonic.nanosecondsValue, duration.monotonic.nanosecondsValue)
    }

    func hangUpdated(at: EmbraceClock, duration: EmbraceClock) {
        lock.lock()
        _hangUpdatedCalled = true
        _hangUpdatedCallCount += 1
        _lastUpdateTime = at.monotonic.nanosecondsValue
        _lastHangDuration = duration.monotonic.nanosecondsValue
        let callback = _onHangUpdated
        lock.unlock()

        callback?(at.monotonic.nanosecondsValue, duration.monotonic.nanosecondsValue)
    }

    func hangEnded(at: EmbraceClock, duration: EmbraceClock) {
        lock.lock()
        _hangEndedCalled = true
        _hangEndedCallCount += 1
        _lastEndTime = at.monotonic.nanosecondsValue
        _lastHangDuration = duration.monotonic.nanosecondsValue
        let callback = _onHangEnded
        lock.unlock()

        callback?(at.monotonic.nanosecondsValue, duration.monotonic.nanosecondsValue)
    }
}
