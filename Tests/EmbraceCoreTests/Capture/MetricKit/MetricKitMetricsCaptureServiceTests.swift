//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class MetricKitMetricsCaptureServiceTests: XCTestCase {

    func options(
        provider: MetricKitPayloadProvider,
        fetcher: EmbraceStorageMetadataFetcher? = nil,
        stateProvider: EmbraceMetricKitStateProvider? = nil
    ) -> MetricKitCaptureServiceOptions {
        return MetricKitCaptureServiceOptions(
            payloadProvider: provider,
            metadataFetcher: fetcher,
            stateProvider: stateProvider ?? MockMetricKitStateProvider()
        )
    }

    func test_listener() throws {
        // given a capture service
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitMetricsCaptureService(options: options)

        // when the service is installed
        service.install(otel: nil)

        // then its added as a listener to the metric kit metrics provider
        XCTAssertTrue(provider.didCallAddMetricsListener)
        XCTAssertTrue(provider.lastMetricsListener is MetricKitMetricsCaptureService)
    }

    func test_valid_metric() throws {
        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let stateProvider = MockMetricKitStateProvider()
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitMetricsCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a metric payload
        service.didReceive(metric: TestConstants.data)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .info)
        XCTAssertEqual(log.type, .metricKitMetrics)
        XCTAssertEqual(log.attributes["emb.state"] as! String, "unknown")
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"] as! String, "metrickit")
        XCTAssertEqual(log.attributes["emb.payload"] as! String, "test")
    }

    func test_not_started() throws {
        // given a capture service that is not started
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitMetricsCaptureService(options: options)
        service.install(otel: otel)

        // when the service receives a metric payload
        service.didReceive(metric: TestConstants.data)

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
        let service = MetricKitMetricsCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a metric payload
        service.didReceive(metric: TestConstants.data)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_remote_config_disabled_2() throws {
        // given remote config disabled
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.isMetricKitEnabled = true
        stateProvider.isMetricKitInternalMetricsCaptureEnabled = false

        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitMetricsCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a metric payload
        service.didReceive(metric: TestConstants.data)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_with_storage() throws {
        // given a capture service with storage
        let storage = try EmbraceStorage.createInMemoryDb()
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider, fetcher: storage)
        let service = MetricKitMetricsCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a metric payload
        service.didReceive(metric: TestConstants.data)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .info)
        XCTAssertEqual(log.type, .metricKitMetrics)
        XCTAssertEqual(log.attributes["emb.state"] as! String, "unknown")
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"] as! String, "metrickit")
        XCTAssertEqual(log.attributes["emb.payload"] as! String, "test")
    }
}
