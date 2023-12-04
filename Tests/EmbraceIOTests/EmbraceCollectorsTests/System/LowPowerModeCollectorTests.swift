//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
import EmbraceStorage
import OpenTelemetryApi
@testable import EmbraceOTel
@testable import EmbraceIO

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

    override func setUpWithError() throws {
        provider.isLowPowerModeEnabled = false

        let storage = try EmbraceStorage(options: .init(named: #file))
        EmbraceOTel.setup(spanProcessor: .with(storage: storage))
    }

    func test_fetchOnStart_modeEnabled() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then a span is started correctly
        XCTAssertNotNil(collector.currentSpan)
        XCTAssertEqual(collector.currentSpan!.name, "emb-device-low-power")

        let span = collector.currentSpan as! RecordingSpan
        XCTAssertEqual(span.spanData.attributes["emb.type"], .string("performance"))
        XCTAssertEqual(span.spanData.attributes["start_reason"], .string("system_query"))
    }

    func test_fetchOnStart_modeDisabled() {
        // given low power mode disabled
        provider.isLowPowerModeEnabled = false

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then a span is not started
        XCTAssertNil(collector.currentSpan)
    }

    func test_startedFlow() {
        provider.isLowPowerModeEnabled = true

        // when installing a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)

        // then its not started
        XCTAssertFalse(collector.started)

        // when low power mode changes
        provider.isLowPowerModeEnabled = false

        // then it is not captued
        XCTAssertNil(collector.currentSpan)

        // when it is started
        collector.start()

        // then it correctly starts
        XCTAssertTrue(collector.started)

        // when low power mode changes
        provider.isLowPowerModeEnabled = true

        // then it is captued
        XCTAssertNotNil(collector.currentSpan)
    }

    func test_stop() {
        provider.isLowPowerModeEnabled = false

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then it correctly starts
        XCTAssertTrue(collector.started)

        // when it is stopped
        collector.stop()

        // then it stops
        XCTAssertFalse(collector.started)

        // when low power mode changes
        provider.isLowPowerModeEnabled = true

        // then it is not captued
        XCTAssertNil(collector.currentSpan)
    }

    func test_systemEvent_modeEnabled() {
        // given low power mode disabled
        provider.isLowPowerModeEnabled = false

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then a span is not started
        XCTAssertNil(collector.currentSpan)

        // when low power mode is enabled
        provider.isLowPowerModeEnabled = true

        // then a span is started correctly
        XCTAssertNotNil(collector.currentSpan)
        XCTAssertEqual(collector.currentSpan!.name, "emb-device-low-power")

        let span = collector.currentSpan as! RecordingSpan
        XCTAssertEqual(span.spanData.attributes["emb.type"], .string("performance"))
        XCTAssertEqual(span.spanData.attributes["start_reason"], .string("system_notification"))
    }

    func test_systemEvent_modeDisabled() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then a span is started
        let span = collector.currentSpan
        XCTAssertNotNil(span)

        // when low power mode is disabled
        provider.isLowPowerModeEnabled = false

        // then the span is ended
        XCTAssertNotNil((span as! RecordingSpan).endTime)
        XCTAssertNil(collector.currentSpan)
    }

    func test_stopCollector_endsSpan() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then a span is started
        let span = collector.currentSpan
        XCTAssertNotNil(span)

        // when the collector is stoped
        collector.stop()

        // then the span is ended
        XCTAssertNotNil((span as! RecordingSpan).endTime)
        XCTAssertNil(collector.currentSpan)
    }

    func test_shutdownCollector_endsSpan() {
        // given low power mode enabled
        provider.isLowPowerModeEnabled = true

        // when starting a collector
        let collector = LowPowerModeCollector(provider: provider)
        collector.install(context: .testContext)
        collector.start()

        // then a span is started
        let span = collector.currentSpan
        XCTAssertNotNil(span)

        // when the collector is stoped
        collector.uninstall()

        // then the span is ended
        XCTAssertNotNil((span as! RecordingSpan).endTime)
        XCTAssertNil(collector.currentSpan)
    }
}

// swiftlint:enable force_cast
