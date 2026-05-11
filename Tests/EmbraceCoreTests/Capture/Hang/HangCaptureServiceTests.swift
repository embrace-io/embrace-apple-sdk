//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import OpenTelemetryApi
    import OpenTelemetrySdk
    import TestSupport
    import XCTest

    @testable import EmbraceCore
    @testable import EmbraceOTelInternal

    // MARK: - HangCaptureService Tests

    final class HangCaptureServiceTests: XCTestCase {

        private var otel: MockEmbraceOpenTelemetry!

        override func setUp() {
            super.setUp()
            otel = MockEmbraceOpenTelemetry()
        }

        override func tearDown() {
            otel = nil
            super.tearDown()
        }

        private func makeInstalledService(limits: HangLimits = HangLimits()) -> HangCaptureService {
            let service = HangCaptureService(limits: limits)
            service.install(otel: otel)
            service.start()
            return service
        }

        // MARK: - Config

        func test_onConfigUpdated_updatesHangThreshold() {
            let service = HangCaptureService(limits: HangLimits(hangThreshold: 0.249))

            let newLimits = HangLimits(hangThreshold: 0.5)
            let mockConfig = MockEmbraceConfigurable(hangLimits: newLimits)
            service.onConfigUpdated(mockConfig)

            XCTAssertEqual(service.limits.hangThreshold, 0.5)
        }

        // MARK: - Span lifecycle

        func test_hangStarted_createsSpan() {
            let service = makeInstalledService()

            service.hangStarted(at: Date(), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                self.otel.spanProcessor.startedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            XCTAssertEqual(otel.spanProcessor.startedSpans.filter { $0.name == SpanSemantics.Hang.name }.count, 1)
        }

        func test_hangEnded_endsSpan() {
            let service = makeInstalledService()
            let start = Date()

            service.hangStarted(at: start, duration: 0.5)
            service.hangEnded(at: start.addingTimeInterval(0.5), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                self.otel.spanProcessor.endedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            let span = otel.spanProcessor.endedSpans.first { $0.name == SpanSemantics.Hang.name }
            XCTAssertNotNil(span)
            XCTAssertEqual(span?.startTime, start)
            XCTAssertEqual(span?.endTime, start.addingTimeInterval(0.5))
        }

        func test_hangEnded_withoutHangStarted_doesNotCrash() {
            let service = makeInstalledService()
            // No prior hangStarted — should silently no-op, not crash
            service.hangEnded(at: Date(), duration: 0.5)
            // Allow the spanQueue to drain
            wait(delay: 0.2)
        }

        func test_hangStarted_withoutOTel_doesNotCrash() {
            // Service never installed — buildSpan returns nil, should not crash
            let service = HangCaptureService()
            service.hangStarted(at: Date(), duration: 0.5)
            wait(delay: 0.2)
        }

        // MARK: - Per-session limit

        func test_perSessionLimit_dropsExcessHangs() {
            let service = makeInstalledService(limits: HangLimits(hangThreshold: 0.249, hangPerSession: 2))

            service.hangStarted(at: Date(), duration: 0.5)
            service.hangEnded(at: Date(), duration: 0.5)

            service.hangStarted(at: Date(), duration: 0.5)
            service.hangEnded(at: Date(), duration: 0.5)

            // Third hang exceeds limit — should be dropped
            service.hangStarted(at: Date(), duration: 0.5)
            service.hangEnded(at: Date(), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                self.otel.spanProcessor.endedSpans.filter { $0.name == SpanSemantics.Hang.name }.count >= 2
            }

            // Give extra time to ensure no third span appears
            wait(delay: 0.3)
            XCTAssertEqual(otel.spanProcessor.endedSpans.filter { $0.name == SpanSemantics.Hang.name }.count, 2)
        }

        func test_onSessionStart_resetsHangCount() {
            let service = makeInstalledService(limits: HangLimits(hangThreshold: 0.249, hangPerSession: 1))
            let mockSession = MockSession.with(id: .random, state: .foreground)

            // Use the one allowed hang
            service.hangStarted(at: Date(), duration: 0.5)
            service.hangEnded(at: Date(), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                self.otel.spanProcessor.endedSpans.filter { $0.name == SpanSemantics.Hang.name }.count == 1
            }

            // Reset via new session
            service.onSessionStart(mockSession)

            // A new hang should now be captured
            service.hangStarted(at: Date(), duration: 0.5)
            service.hangEnded(at: Date(), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                self.otel.spanProcessor.endedSpans.filter { $0.name == SpanSemantics.Hang.name }.count == 2
            }

            XCTAssertEqual(otel.spanProcessor.endedSpans.filter { $0.name == SpanSemantics.Hang.name }.count, 2)
        }

        // MARK: - Config disables monitor

        func test_onConfigUpdated_disablesHangs_whenPerSessionIsZero() {
            let service = makeInstalledService()

            let disabledLimits = HangLimits(hangThreshold: 0.249, hangPerSession: 0)
            let mockConfig = MockEmbraceConfigurable(hangLimits: disabledLimits)
            service.onConfigUpdated(mockConfig)

            XCTAssertEqual(service.limits.hangPerSession, 0)

            // Hangs should now be dropped
            service.hangStarted(at: Date(), duration: 0.5)
            service.hangEnded(at: Date(), duration: 0.5)

            wait(delay: 0.3)
            XCTAssertEqual(otel.spanProcessor.startedSpans.filter { $0.name == SpanSemantics.Hang.name }.count, 0)
        }
    }

#endif  // !os(watchOS)

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
