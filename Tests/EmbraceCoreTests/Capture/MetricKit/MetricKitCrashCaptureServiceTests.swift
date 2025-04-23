//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommonInternal
@testable import EmbraceCore
import EmbraceStorageInternal

class MetricKitCrashCaptureServiceTests: XCTestCase {

    func options(provider: MetricKitCrashPayloadProvider, 
                 fetcher: EmbraceStorageMetadataFetcher? = nil,
                 stateProvider: EmbraceMetricKitStateProvider? = nil
    ) -> MetricKitCrashCaptureService.Options {
        return MetricKitCrashCaptureService.Options(
            crashProvider: provider,
            metadataFetcher: fetcher,
            stateProvider: stateProvider ?? MockMetricKitStateProvider(),
            signals: [ 9 ]
        )
    }

    func test_listener() throws {
        // given a capture service
        let provider = MockMetricKitCrashPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitCrashCaptureService(options: options)

        // when the service is installed
        service.install(otel: nil)

        // then its added as a listener to the metric kit crash provider
        XCTAssertTrue(provider.didCallAddListener)
        XCTAssertTrue(provider.lastListener is MetricKitCrashCaptureService)
    }

    func test_valid_signal() throws {
        // given a capture service
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockMetricKitCrashPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the right signal
        service.didReceive(payload: TestConstants.data, signal: 9, sessionId: nil)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .fatal)
        XCTAssertEqual(log.embType, .crash)
        XCTAssertEqual(log.attributes["emb.state"], .string("unknown"))
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"], .string("metrickit"))
        XCTAssertEqual(log.attributes["emb.payload"], .string("test"))
    }

    func test_invalid_signal() throws {
        // given a capture service
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockMetricKitCrashPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the incorrect signal
        service.didReceive(payload: TestConstants.data, signal: 11, sessionId: nil)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_not_started() throws {
        // given a capture service that is not started
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockMetricKitCrashPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)

        // when the service receives a payload with the right signal
        service.didReceive(payload: TestConstants.data, signal: 9, sessionId: nil)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_remote_config_disabled() throws {
        // given remote config disabled
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.isMetricKitEnabled = false

        // given a capture service
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockMetricKitCrashPayloadProvider()
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the correct signal
        service.didReceive(payload: TestConstants.data, signal: 9, sessionId: nil)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_session_attributes() throws {
        // given a corresponding session in storage with metadata
        let storage = try EmbraceStorage.createInMemoryDb()
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        storage.addMetadata(
            key: "test1",
            value: "metadata",
            type: .customProperty,
            lifespan: .session,
            lifespanId: TestConstants.sessionId.toString
        )
        storage.addMetadata(
            key: "test2",
            value: "metadata",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.hex
        )

        // given a capture service
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockMetricKitCrashPayloadProvider()
        let options = options(provider: provider, fetcher: storage)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the right signal and session id
        service.didReceive(payload: TestConstants.data, signal: 9, sessionId: TestConstants.sessionId)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .fatal)
        XCTAssertEqual(log.embType, .crash)
        XCTAssertEqual(log.attributes["emb.state"], .string("unknown"))
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"], .string("metrickit"))
        XCTAssertEqual(log.attributes["emb.payload"], .string("test"))
        XCTAssertEqual(log.attributes["emb.properties.test1"], .string("metadata"))
        XCTAssertEqual(log.attributes["emb.properties.test2"], .string("metadata"))
    }
}


class MockMetricKitCrashPayloadProvider: MetricKitCrashPayloadProvider {

    var didCallAddListener: Bool = false
    var lastListener: AnyObject? = nil
    func add(listener: any MetricKitCrashPayloadListener) {
        didCallAddListener = true
        lastListener = listener
    }
}

class MockMetricKitStateProvider: EmbraceMetricKitStateProvider {
    var isMetricKitEnabled: Bool = true
}
