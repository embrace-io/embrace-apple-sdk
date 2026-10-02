//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import EmbraceStorageInternal

class DummyEmbraceResourceProvider: EmbraceResourceProvider {
    func getResource() -> Resource { Resource() }
}

class EmbraceLoggerSharedStateTests: XCTestCase {
    private var sut: DefaultEmbraceLogSharedState!
    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_default_hasDefaultEmbraceLoggerConfig() throws {
        try whenInvokingDefaultEmbraceLoggerSharedState()
        thenConfig(is: DefaultEmbraceLoggerConfig())
    }

    func test_default_hasNoProcessors() throws {
        try whenInvokingDefaultEmbraceLoggerSharedState()
        thenProcessorsArrayHasDefaultProcessors()
    }

    func test_create_storesLogsInlineAndQueuesTheCustomerExporter() throws {
        let batcher = SpyLogBatcher()
        let customerExporter = InMemoryLogRecordExporter()
        sut = try .create(
            storage: EmbraceStorage.createInMemoryDb(),
            batcher: batcher,
            exporter: customerExporter,
            sdkStateProvider: sdkStateProvider
        )

        XCTAssertEqual(sut.processors.count, 2)
        let queued = try XCTUnwrap(sut.processors[1] as? QueuedLogRecordProcessor)

        // Hold the customer queue so anything forwarded through it can't run yet.
        let gate = DispatchSemaphore(value: 0)
        queued.queue.async {
            // timed-wait: bounded so the queue is still released if the test exits before `gate.signal()`.
            _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        }

        let log = ReadableLogRecord(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: Date(),
            severity: .info,
            body: .string("example"),
            attributes: [:]
        )
        sut.processors.forEach { $0.onEmit(logRecord: log) }

        XCTAssertEqual(batcher.addLogRecordInvocationCount, 1)
        XCTAssertTrue(customerExporter.finishedLogRecords.isEmpty)

        gate.signal()
        _ = queued.forceFlush()

        XCTAssertEqual(customerExporter.finishedLogRecords.map(\.body), [.string("example")])
    }

    func test_create_withoutCustomerProcessorsOrExporters_hasOnlyTheInlineProcessor() throws {
        try whenInvokingDefaultEmbraceLoggerSharedState()
        XCTAssertEqual(sut.processors.count, 1)
        XCTAssertTrue(sut.processors.first is SingleLogRecordProcessor)
    }

    func test_updateConfig_thenOriginalConfigShouldBeUpdated() {
        class ZeroedConfig: EmbraceLoggerConfig {
            var batchLifetimeInSeconds: Int = 0
            var maximumTimeBetweenLogsInSeconds: Int = 0
            var maximumMessageLength: Int = 0
            var maximumAttributes: Int = 0
            var logAmountLimit: Int = 0
        }
        givenEmbraceLoggerSharedState(config: DefaultEmbraceLoggerConfig())
        whenInvokingUpdate(withConfig: ZeroedConfig())
        thenConfig(is: ZeroedConfig())
    }
}

extension EmbraceLoggerSharedStateTests {
    fileprivate func givenEmbraceLoggerSharedState(config: any EmbraceLoggerConfig) {
        sut = .init(config: config, processors: [], resourceProvider: DummyEmbraceResourceProvider())
    }

    fileprivate func whenInvokingUpdate(withConfig config: any EmbraceLoggerConfig) {
        sut.update(config)
    }

    fileprivate func whenInvokingDefaultEmbraceLoggerSharedState() throws {
        sut = try .create(
            storage: EmbraceStorage.createInMemoryDb(),
            batcher: SpyLogBatcher(),
            sdkStateProvider: sdkStateProvider
        )
    }

    fileprivate func thenConfig(is config: any EmbraceLoggerConfig) {
        XCTAssertEqual(sut.config.logAmountLimit, config.logAmountLimit)
    }

    fileprivate func thenProcessorsArrayHasDefaultProcessors() {
        XCTAssertFalse(sut.processors.isEmpty)
    }
}
