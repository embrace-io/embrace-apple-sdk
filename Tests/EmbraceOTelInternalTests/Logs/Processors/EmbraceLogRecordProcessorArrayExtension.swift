//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

class EmbraceLogRecordProcessorArrayExtensionTests: XCTestCase {

    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_onDefaultWithoutCustomerProcessorsOrExporters_returnsOnlyTheInlineProcessor() throws {
        let processors: [LogRecordProcessor] = .default(embraceExporters: [], sdkStateProvider: sdkStateProvider)
        XCTAssertEqual(processors.count, 1)
        XCTAssertTrue(try XCTUnwrap(processors.first) is SingleLogRecordProcessor)
    }

    func test_onDefaultWithCustomerExporter_queuesOnlyTheCustomerExporter() throws {
        let embraceExporter = InMemoryLogRecordExporter()
        let customerExporter = InMemoryLogRecordExporter()
        let processors: [LogRecordProcessor] = .default(
            embraceExporters: [embraceExporter],
            exporters: [customerExporter],
            sdkStateProvider: sdkStateProvider
        )

        XCTAssertEqual(processors.count, 2)
        XCTAssertTrue(processors[0] is SingleLogRecordProcessor)
        let queued = try XCTUnwrap(processors[1] as? QueuedLogRecordProcessor)

        // Hold the customer queue so anything forwarded through it can't run yet.
        let gate = hold(queued)

        processors.forEach { $0.onEmit(logRecord: .log(withTestId: "12345")) }

        XCTAssertEqual(embraceExporter.finishedLogRecords.count, 1)
        XCTAssertEqual(customerExporter.finishedLogRecords.count, 0)

        gate.signal()
        _ = queued.forceFlush()

        XCTAssertEqual(try customerExporter.finishedLogRecords.first?.getTestId(), "12345")
    }

    func test_onDefaultWithCustomerProcessor_queuesTheCustomerProcessor() throws {
        let customerProcessor = SpyLoggerProcessor()
        let processors: [LogRecordProcessor] = .default(
            embraceExporters: [],
            processors: [customerProcessor],
            sdkStateProvider: sdkStateProvider
        )

        XCTAssertEqual(processors.count, 2)
        let queued = try XCTUnwrap(processors[1] as? QueuedLogRecordProcessor)

        let gate = hold(queued)

        processors.forEach { $0.onEmit(logRecord: .log(withTestId: "12345")) }

        XCTAssertFalse(customerProcessor.didCallOnEmit)

        gate.signal()
        _ = queued.forceFlush()

        XCTAssertEqual(try customerProcessor.receivedLogRecord?.getTestId(), "12345")
    }

    func test_onDefault_whenSDKIsDisabled_noExporterReceivesTheLog() {
        let embraceExporter = InMemoryLogRecordExporter()
        let customerExporter = InMemoryLogRecordExporter()
        let processors: [LogRecordProcessor] = .default(
            embraceExporters: [embraceExporter],
            exporters: [customerExporter],
            sdkStateProvider: sdkStateProvider
        )
        sdkStateProvider.isEnabled = false

        processors.forEach { $0.onEmit(logRecord: .log(withTestId: "12345")) }
        // `forceFlush` returns `.failure` while the SDK is disabled, but still drains the queue.
        processors.forEach { _ = $0.forceFlush() }

        XCTAssertTrue(embraceExporter.finishedLogRecords.isEmpty)
        XCTAssertTrue(customerExporter.finishedLogRecords.isEmpty)
    }

    // A customer exporter that re-enters the SDK queue it was called from (for example by starting a
    // URLSession task, which the network capture handles with `queue.sync`) traps if it runs on that queue.
    func test_onDefault_whenEmittedFromAnSDKQueue_customerExporterRunsOffThatQueue() {
        let sdkQueue = DispatchQueue(label: "test.sdk-queue")
        let sdkQueueKey = DispatchSpecificKey<Bool>()
        sdkQueue.setSpecific(key: sdkQueueKey, value: true)

        let customerExporter = QueueCheckingExporter(key: sdkQueueKey)
        let processors: [LogRecordProcessor] = .default(
            embraceExporters: [],
            exporters: [customerExporter],
            sdkStateProvider: sdkStateProvider
        )

        sdkQueue.sync {
            processors.forEach { $0.onEmit(logRecord: .log(withTestId: "12345")) }
        }
        processors.forEach { _ = $0.forceFlush() }

        XCTAssertEqual(customerExporter.ranOnKeyedQueue, [false])
    }

    /// Blocks `queued`'s queue until the returned semaphore is signalled.
    private func hold(_ queued: QueuedLogRecordProcessor) -> DispatchSemaphore {
        let gate = DispatchSemaphore(value: 0)
        queued.queue.async {
            // timed-wait: bounded so the queue is still released if the test exits before `gate.signal()`.
            _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        }
        return gate
    }
}

/// Records, for each export, whether it ran on the queue tagged with `key`.
private class QueueCheckingExporter: LogRecordExporter {
    private let key: DispatchSpecificKey<Bool>
    private(set) var ranOnKeyedQueue: [Bool] = []

    init(key: DispatchSpecificKey<Bool>) {
        self.key = key
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        ranOnKeyedQueue.append(DispatchQueue.getSpecific(key: key) == true)
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {}

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}
