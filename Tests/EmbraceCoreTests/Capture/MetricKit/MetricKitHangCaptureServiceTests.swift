//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class MetricKitHangCaptureServiceTests: XCTestCase {

    func options(
        provider: MetricKitPayloadProvider,
        fetcher: EmbraceStorageMetadataFetcher? = nil,
        stateProvider: EmbraceMetricKitStateProvider? = nil
    ) -> MetricKitCaptureServiceOptions {
        MetricKitCaptureServiceOptions(
            payloadProvider: provider,
            metadataFetcher: fetcher,
            stateProvider: stateProvider ?? MockMetricKitStateProvider()
        )
    }

    func test_listener() throws {
        // given a capture service
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitHangCaptureService(options: options)

        // when the service is installed
        service.install(otel: nil)

        // then its added as a listener to the metric kit crash provider
        XCTAssertTrue(provider.didCallAddHangListener)
        XCTAssertTrue(provider.lastHangListener is MetricKitHangCaptureService)
    }

    func test_log() throws {
        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitHangCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload
        let startTime = Date(timeIntervalSince1970: 40)
        let endTime = Date(timeIntervalSince1970: 50)
        service.didReceive(payload: TestConstants.data, startTime: startTime, endTime: endTime)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .warn)
        XCTAssertEqual(log.type, .hang)
        XCTAssertEqual(log.attributes["emb.state"] as! String, "unknown")
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"] as! String, "metrickit")
        XCTAssertEqual(log.attributes["emb.payload"] as! String, "test")
        XCTAssertNotNil(log.attributes["emb.payload.timestamp"])
        XCTAssertEqual(
            log.attributes["diagnostic.timestamp_start"] as! String, String(startTime.nanosecondsSince1970Truncated))
        XCTAssertEqual(
            log.attributes["diagnostic.timestamp_end"] as! String, String(endTime.nanosecondsSince1970Truncated))
    }

    func test_not_started() throws {
        // given a capture service that is not started
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitHangCaptureService(options: options)
        service.install(otel: otel)

        // when the service receives a payload
        let startTime = Date(timeIntervalSince1970: 40)
        let endTime = Date(timeIntervalSince1970: 50)
        service.didReceive(payload: TestConstants.data, startTime: startTime, endTime: endTime)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_remote_config_disabled() throws {
        // given remote config disabled
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.isMetricKitEnabled = false

        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitHangCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the correct signal
        let startTime = Date(timeIntervalSince1970: 40)
        let endTime = Date(timeIntervalSince1970: 50)
        service.didReceive(payload: TestConstants.data, startTime: startTime, endTime: endTime)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_remote_config_disabled_2() throws {
        // given remote config disabled
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.isMetricKitEnabled = true
        stateProvider.isMetricKitHangCaptureEnabled = false

        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitHangCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the correct signal
        let startTime = Date(timeIntervalSince1970: 40)
        let endTime = Date(timeIntervalSince1970: 50)
        service.didReceive(payload: TestConstants.data, startTime: startTime, endTime: endTime)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }
}
