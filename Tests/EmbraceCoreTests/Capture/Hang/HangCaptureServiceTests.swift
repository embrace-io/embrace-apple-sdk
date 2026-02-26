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
    private var _onHangStarted: ((Date, TimeInterval) -> Void)?
    var onHangStarted: ((Date, TimeInterval) -> Void)? {
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

    private var _onHangUpdated: ((Date, TimeInterval) -> Void)?
    var onHangUpdated: ((Date, TimeInterval) -> Void)? {
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

    private var _onHangEnded: ((Date, TimeInterval) -> Void)?
    var onHangEnded: ((Date, TimeInterval) -> Void)? {
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

    private var _lastHangDuration: TimeInterval = 0
    var lastHangDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return _lastHangDuration
    }

    func hangStarted(at: Date, duration: TimeInterval) {
        lock.lock()
        _hangStartedCalled = true
        _hangStartedCallCount += 1
        _lastHangDuration = duration
        let callback = _onHangStarted
        lock.unlock()

        callback?(at, duration)
    }

    func hangUpdated(at: Date, duration: TimeInterval) {
        lock.lock()
        _hangUpdatedCalled = true
        _hangUpdatedCallCount += 1
        _lastHangDuration = duration
        let callback = _onHangUpdated
        lock.unlock()

        callback?(at, duration)
    }

    func hangEnded(at: Date, duration: TimeInterval) {
        lock.lock()
        _hangEndedCalled = true
        _hangEndedCallCount += 1
        _lastHangDuration = duration
        let callback = _onHangEnded
        lock.unlock()

        callback?(at, duration)
    }
}
