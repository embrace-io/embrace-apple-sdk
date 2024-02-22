//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
import OpenTelemetryApi
@testable import EmbraceOTel
@testable import EmbraceCore

// swiftlint:disable force_cast

class MockPowerModeProvider: PowerModeProvider {
    var isLowPowerModeEnabled = false {
        didSet {
            NotificationCenter.default.post(Notification(name: NSNotification.Name.NSProcessInfoPowerStateDidChange))
        }
    }
}

class LowPowerModeCollectorTests: XCTestCase {

    let provider = MockPowerModeProvider()

    private var processor: MockSpanProcessor!
    private var otel: EmbraceOpenTelemetryMock!
    private var otelProvider: EmbraceOtelProviderMock!

    override func setUpWithError() throws {
        provider.isLowPowerModeEnabled = false

        processor = MockSpanProcessor()
        otel = EmbraceOpenTelemetryMock(processor: processor)
        otelProvider = EmbraceOtelProviderMock(embraceOtel: otel)
    }

    func test_fetchOnStart_modeEnabled() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then a span is started correctly
        XCTAssertNotNil(service.currentSpan)
        XCTAssertEqual(service.currentSpan!.name, "emb-device-low-power")

        let span = service.currentSpan as! ReadableSpan
        XCTAssertEqual(span.toSpanData().attributes["emb.type"], .string("performance"))
        XCTAssertEqual(span.toSpanData().attributes["start_reason"], .string("system_query"))
    }

    func test_fetchOnStart_modeDisabled() {
        // given low power mode disabled
        provider.isLowPowerModeEnabled = false

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then a span is not started
        XCTAssertNil(service.currentSpan)
    }

    func test_startedFlow() {
        provider.isLowPowerModeEnabled = true

        // when installing a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)

        // then its not started
        XCTAssertFalse(service.started)

        // when low power mode changes
        provider.isLowPowerModeEnabled = false

        // then it is not captued
        XCTAssertNil(service.currentSpan)

        // when it is started
        service.start()

        // then it correctly starts
        XCTAssertTrue(service.started)

        // when low power mode changes
        provider.isLowPowerModeEnabled = true

        // then it is captued
        XCTAssertNotNil(service.currentSpan)
    }

    func test_stop() {
        provider.isLowPowerModeEnabled = false

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then it correctly starts
        XCTAssertTrue(service.started)

        // when it is stopped
        service.stop()

        // then it stops
        XCTAssertFalse(service.started)

        // when low power mode changes
        provider.isLowPowerModeEnabled = true

        // then it is not captued
        XCTAssertNil(service.currentSpan)
    }

    func test_systemEvent_modeEnabled() {
        // given low power mode disabled
        provider.isLowPowerModeEnabled = false

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then a span is not started
        XCTAssertNil(service.currentSpan)

        // when low power mode is enabled
        provider.isLowPowerModeEnabled = true

        // then a span is started correctly
        XCTAssertNotNil(service.currentSpan)
        XCTAssertEqual(service.currentSpan!.name, "emb-device-low-power")

        let span = service.currentSpan as! ReadableSpan
        XCTAssertEqual(span.toSpanData().attributes["emb.type"], .string("performance"))
        XCTAssertEqual(span.toSpanData().attributes["start_reason"], .string("system_notification"))
    }

    func test_systemEvent_modeDisabled() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then a span is started
        let span = service.currentSpan
        XCTAssertNotNil(span)

        // when low power mode is disabled
        provider.isLowPowerModeEnabled = false

        // then the span is ended
        XCTAssertTrue((span as! ReadableSpan).hasEnded)
        XCTAssertNil(service.currentSpan)
    }

    func test_stopService_endsSpan() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then a span is started
        let span = service.currentSpan
        XCTAssertNotNil(span)

        // when the service is stoped
        service.stop()

        // then the span is ended
        XCTAssertTrue((span as! ReadableSpan).hasEnded)
        XCTAssertNil(service.currentSpan)
    }

    func test_shutdownService_endsSpan() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a service
        let service = LowPowerModeCaptureService(provider: provider, otelProvider: otelProvider)
        service.install(context: .testContext)
        service.start()

        // then a span is started
        let span = service.currentSpan
        XCTAssertNotNil(span)

        // when the service is stoped
        service.uninstall()

        // then the span is ended
        XCTAssertTrue((span as! ReadableSpan).hasEnded)
        XCTAssertNil(service.currentSpan)
    }
}

// swiftlint:enable force_cast
