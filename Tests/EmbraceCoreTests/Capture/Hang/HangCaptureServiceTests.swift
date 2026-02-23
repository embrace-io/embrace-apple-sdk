import EmbraceCommonInternal
import EmbraceConfiguration
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal

// MARK: - HangCaptureService Tests

final class HangCaptureServiceTests: XCTestCase {

    func test_onConfigUpdated_updatesHangThreshold() {
        let service = HangCaptureService(limits: HangLimits(hangThreshold: 0.249))

        let newLimits = HangLimits(hangThreshold: 0.5)
        let mockConfig = MockEmbraceConfigurable(hangLimits: newLimits)
        service.onConfigUpdated(mockConfig)

        XCTAssertEqual(service.limits.hangThreshold, 0.5)
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
