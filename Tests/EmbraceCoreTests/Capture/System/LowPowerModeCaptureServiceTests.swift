//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class MockPowerModeProvider: PowerModeProvider {
    var isLowPowerModeEnabled = false {
        didSet {
            NotificationCenter.default.post(Notification(name: NSNotification.Name.NSProcessInfoPowerStateDidChange))
        }
    }
}

class LowPowerModeCollectorTests: XCTestCase {

    let provider = MockPowerModeProvider()
    private var otel: MockOTelSignalsHandler!

    override func setUpWithError() throws {
        provider.isLowPowerModeEnabled = false
        otel = MockOTelSignalsHandler()
    }

    override func tearDownWithError() throws {
        otel = nil
    }

    func test_fetchOnStart_modeEnabled() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then a span is started correctly
        XCTAssertNotNil(service.currentSpan)
        XCTAssertEqual(service.currentSpan!.name, "emb-device-low-power")

        XCTAssertEqual(service.currentSpan!.type, .lowPower)
        XCTAssertEqual(service.currentSpan!.attributes["start_reason"] as! String, "system_query")
    }

    func test_fetchOnStart_modeDisabled() {
        // given low power mode disabled
        provider.isLowPowerModeEnabled = false

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then a span is not started
        XCTAssertNil(service.currentSpan)
    }

    func test_startedFlow() {
        provider.isLowPowerModeEnabled = true

        // when installing a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)

        // then its not started
        XCTAssertFalse(service.state.load() == .active)

        // when low power mode changes
        provider.isLowPowerModeEnabled = false

        // then it is not captued
        XCTAssertNil(service.currentSpan)

        // when it is started
        service.start()

        // then it correctly starts
        XCTAssertTrue(service.state.load() == .active)

        // when low power mode changes
        provider.isLowPowerModeEnabled = true

        // then it is captured
        XCTAssertNotNil(service.currentSpan)
    }

    func test_stop() {
        provider.isLowPowerModeEnabled = false

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then it correctly starts
        XCTAssertTrue(service.state.load() == .active)

        // when it is stopped
        service.stop()

        // then it stops
        XCTAssertFalse(service.state.load() == .active)

        // when low power mode changes
        provider.isLowPowerModeEnabled = true

        // then it is not captured
        XCTAssertNil(service.currentSpan)
    }

    func test_systemEvent_modeEnabled() {
        // given low power mode disabled
        provider.isLowPowerModeEnabled = false

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then a span is not started
        XCTAssertNil(service.currentSpan)

        // when low power mode is enabled
        provider.isLowPowerModeEnabled = true

        // then a span is started correctly
        XCTAssertNotNil(service.currentSpan)
        XCTAssertEqual(service.currentSpan!.name, "emb-device-low-power")

        XCTAssertEqual(service.currentSpan!.type, .lowPower)
        XCTAssertEqual(service.currentSpan!.attributes["start_reason"] as! String, "system_notification")
    }

    func test_systemEvent_modeDisabled() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then a span is started
        let span = service.currentSpan
        XCTAssertNotNil(span)

        // when low power mode is disabled
        provider.isLowPowerModeEnabled = false

        // then the span is ended
        XCTAssertNotNil(span!.endTime)
        XCTAssertNil(service.currentSpan)
    }

    func test_stopService_endsSpan() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then a span is started
        let span = service.currentSpan
        XCTAssertNotNil(span)

        // when the service is stopped
        service.stop()

        // then the span is ended
        XCTAssertNotNil(span!.endTime)
        XCTAssertNil(service.currentSpan)
    }

    func test_endSpan_endsSpanOutsideOfLock() {
        // given a service with an active span
        provider.isLowPowerModeEnabled = true

        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        let span = service.currentSpan
        XCTAssertNotNil(span)

        // and a span processor that checks if the service's lock is free when a span ends
        var lockWasFree: Bool?
        otel.onSpanEndedCallback = { _ in
            lockWasFree = service._currentSpan.isLockFree
        }
        defer { otel.onSpanEndedCallback = nil }

        // when the span is ended
        service.endSpan()

        // then it is ended without holding the lock
        XCTAssertNotNil(span!.endTime)
        XCTAssertEqual(lockWasFree, true)
        XCTAssertNil(service.currentSpan)
    }

    func test_startSpan_startsSpanOutsideOfLock() {
        // given an active service
        provider.isLowPowerModeEnabled = false

        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // and a span processor that checks if the service's lock is free when a span starts
        var lockWasFree: Bool?
        otel.onSpanStartedCallback = { _ in
            lockWasFree = service._currentSpan.isLockFree
        }
        defer { otel.onSpanStartedCallback = nil }

        // when a span is started
        service.startSpan()

        // then it is started without holding the lock
        XCTAssertEqual(lockWasFree, true)
        XCTAssertNotNil(service.currentSpan)
    }

    func test_startSpan_endsConcurrentlyStoredSpan() throws {
        // given an active service
        provider.isLowPowerModeEnabled = false

        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // and a span that another thread stores while a new one is being started
        let raced = try otel._createSpan(name: "raced", type: .lowPower, startTime: Date())
        var racedSpanWasStored: Bool?
        otel.onSpanStartedCallback = { _ in
            racedSpanWasStored = service._currentSpan.withLockIfAvailable { $0 = raced } != nil
        }
        defer { otel.onSpanStartedCallback = nil }

        // and a span processor that checks if the service's lock is free when a span ends
        var lockWasFree: [Bool] = []
        otel.onSpanEndedCallback = { _ in
            lockWasFree.append(service._currentSpan.isLockFree)
        }
        defer { otel.onSpanEndedCallback = nil }

        // when a span is started
        service.startSpan()

        // then the raced span is ended without holding the lock and replaced by the new one
        XCTAssertEqual(racedSpanWasStored, true)
        XCTAssertNotNil(raced.endTime)
        XCTAssertEqual(lockWasFree, [true])
        XCTAssertNotNil(service.currentSpan)
        XCTAssertEqual(service.currentSpan?.name, "emb-device-low-power")
        XCTAssertNil(service.currentSpan?.endTime)
    }

    func test_shutdownService_endsSpan() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider)
        service.install(otel: otel)
        service.start()

        // then a span is started
        let span = service.currentSpan
        XCTAssertNotNil(span)

        // when the service is stopped
        service.stop()

        // then the span is ended
        XCTAssertNotNil(span!.endTime)
        XCTAssertNil(service.currentSpan)
    }
}
