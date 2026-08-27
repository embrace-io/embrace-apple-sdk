//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class MetricKitCrashCaptureServiceTests: XCTestCase {

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
        let service = MetricKitCrashCaptureService(options: options)

        // when the service is installed
        service.install(otel: nil)

        // then its added as a listener to the metric kit crash provider
        XCTAssertTrue(provider.didCallAddCrashListener)
        XCTAssertTrue(provider.lastCrashListener is MetricKitCrashCaptureService)
    }

    func test_valid_signal() throws {
        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.metricKitCrashSignals = [3, 5]
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the right signal
        service.didReceive(payload: TestConstants.data, signal: 5, session: nil)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .fatal)
        XCTAssertEqual(log.type, .crash)
        XCTAssertEqual(log.attributes["emb.state"] as! String, "unknown")
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"] as! String, "metrickit")
        XCTAssertEqual(log.attributes["emb.payload"] as! String, "test")
    }

    func test_invalid_signal() throws {
        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.metricKitCrashSignals = [3, 5]
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the incorrect signal
        service.didReceive(payload: TestConstants.data, signal: 11, session: nil)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_not_started() throws {
        // given a capture service that is not started
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)

        // when the service receives a payload with the right signal
        service.didReceive(payload: TestConstants.data, signal: 9, session: nil)

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
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the correct signal
        service.didReceive(payload: TestConstants.data, signal: 9, session: nil)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_remote_config_disabled_2() throws {
        // given remote config disabled
        let stateProvider = MockMetricKitStateProvider()
        stateProvider.isMetricKitEnabled = true
        stateProvider.isMetricKitCrashCaptureEnabled = false

        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider, stateProvider: stateProvider)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the correct signal
        service.didReceive(payload: TestConstants.data, signal: 9, session: nil)

        // then it doesnt create a log
        XCTAssertEqual(otel.logs.count, 0)
    }

    func test_session_attributes() throws {
        // given a corresponding session in storage with metadata
        let storage = try EmbraceStorage.createInMemoryDb()
        let part = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: TestConstants.processId,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(),
                userSessionId: TestConstants.userSessionId
            )
        )
        storage.addMetadata(
            key: "test1",
            value: "metadata",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "test2",
            value: "metadata",
            type: .customProperty,
            lifespan: .process,
            lifespanId: TestConstants.processId.stringValue
        )

        // given a capture service
        let otel = MockOTelSignalsHandler()
        let provider = MockMetricKitPayloadProvider()
        let options = options(provider: provider, fetcher: storage)
        let service = MetricKitCrashCaptureService(options: options)
        service.install(otel: otel)
        service.start()

        // when the service receives a payload with the right signal, linked to a session part
        service.didReceive(payload: TestConstants.data, signal: 9, session: part)

        // then it creates the corresponding otel log
        let log = otel.logs[0]
        XCTAssertEqual(log.severity, .fatal)
        XCTAssertEqual(log.type, .crash)
        XCTAssertEqual(log.attributes["emb.state"] as! String, "unknown")
        XCTAssertNotNil(log.attributes["log.record.uid"])
        XCTAssertEqual(log.attributes["emb.provider"] as! String, "metrickit")
        XCTAssertEqual(log.attributes["emb.payload"] as! String, "test")
        XCTAssertEqual(log.attributes["emb.properties.test1"] as! String, "metadata")
        XCTAssertEqual(log.attributes["emb.properties.test2"] as! String, "metadata")

        // and the log carries both identities: the user session and the session part
        XCTAssertEqual(log.attributes["session.id"] as! String, TestConstants.userSessionId.stringValue)
        XCTAssertEqual(log.attributes["emb.user_session_id"] as! String, TestConstants.userSessionId.stringValue)
        XCTAssertEqual(log.attributes["emb.session_part_id"] as! String, TestConstants.sessionId.stringValue)
    }
}
