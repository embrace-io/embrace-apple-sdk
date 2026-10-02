//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceOTelBridge
@testable import EmbraceSemantics

final class EmbraceLogProcessorTests: XCTestCase {

    var loggerProvider: LoggerProviderSdk!
    var embraceProcessor: EmbraceLogProcessor!
    var mockDelegate: MockLogProcessorDelegate!
    var otelLogger: Logger!

    override func setUp() {
        super.setUp()
        mockDelegate = MockLogProcessorDelegate()
        embraceProcessor = EmbraceLogProcessor(delegate: mockDelegate)
        loggerProvider = LoggerProviderSdk(logRecordProcessors: [embraceProcessor])
        otelLogger = loggerProvider.loggerBuilder(instrumentationScopeName: "test").build()
    }

    private func emitLog(body: String = "test") {
        otelLogger.logRecordBuilder()
            .setBody(.string(body))
            .setSeverity(.info)
            .emit()
    }

    func test_onEmit_forwardsExternalLogToDelegate() {
        emitLog(body: "hello")
        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        if case let .string(text) = mockDelegate.emittedLogs.first?.body {
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected string body")
        }
    }

    func test_onEmit_skipsInternalLogs() {
        mockDelegate.internalLogBodies = ["internal-log"]
        emitLog(body: "internal-log")
        XCTAssertEqual(mockDelegate.emittedLogs.count, 0)
    }

    func test_multipleExternalLogs_allForwarded() {
        emitLog(body: "first")
        emitLog(body: "second")
        XCTAssertEqual(mockDelegate.emittedLogs.count, 2)
    }

    func test_noDelegate_doesNotCrash() {
        let processor = EmbraceLogProcessor(delegate: nil)
        let provider = LoggerProviderSdk(logRecordProcessors: [processor])
        let logger = provider.loggerBuilder(instrumentationScopeName: "test").build()
        logger.logRecordBuilder().setBody(.string("test")).emit()
        // No crash — test passes
    }

    // MARK: - Attribute injection on external logs

    func test_onEmit_injectsEmbraceAttributesOnExternalLog() {
        mockDelegate.currentSessionState = .background
        mockDelegate.currentSessionId = EmbraceIdentifier(stringValue: "part-123")
        mockDelegate.currentUserSessionId = EmbraceIdentifier(stringValue: "user-123")

        emitLog(body: "external-log")

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        let log = mockDelegate.emittedLogs.first
        XCTAssertEqual(log?.attributes[LogSemantics.keyEmbraceType], .string(EmbraceType.message.rawValue))
        XCTAssertEqual(log?.attributes[LogSemantics.keyState], .string("background"))
        // session.id carries the user-session id; the part id lives under emb.session_part_id.
        XCTAssertEqual(log?.attributes[LogSemantics.keySessionId], .string("user-123"))
        XCTAssertEqual(log?.attributes[LogSemantics.keyUserSessionId], .string("user-123"))
        XCTAssertEqual(log?.attributes[LogSemantics.keyPartId], .string("part-123"))
    }

    // MARK: - Child processor forwarding

    func test_onEmit_forwardsToChildProcessors() {
        let childProcessor = CapturingLogProcessor()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let provider = LoggerProviderSdk(logRecordProcessors: [processor])
        let logger = provider.loggerBuilder(instrumentationScopeName: "test").build()

        logger.logRecordBuilder().setBody(.string("forwarded")).setSeverity(.info).emit()
        processor.waitForAllWork()

        XCTAssertEqual(childProcessor.capturedLogs.count, 1)
        if case let .string(body) = childProcessor.capturedLogs.first?.body {
            XCTAssertEqual(body, "forwarded")
        } else {
            XCTFail("Expected string body")
        }
    }

    // MARK: - Child exporter forwarding

    func test_onEmit_forwardsToChildExporters() {
        let childExporter = CapturingLogExporter()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childExporters: [childExporter])
        let provider = LoggerProviderSdk(logRecordProcessors: [processor])
        let logger = provider.loggerBuilder(instrumentationScopeName: "test").build()

        logger.logRecordBuilder().setBody(.string("exported")).setSeverity(.info).emit()
        processor.waitForAllWork()

        XCTAssertEqual(childExporter.exportedLogs.count, 1)
    }

    // MARK: - Child forwarding runs on the processor queue

    func test_onEmit_returnsWithoutWaitingForChildren_andNotifiesDelegateInline() {
        let blockingProcessor = BlockingLogProcessor()
        let childExporter = CapturingLogExporter()
        let processor = EmbraceLogProcessor(
            delegate: mockDelegate,
            childProcessors: [blockingProcessor],
            childExporters: [childExporter]
        )
        let logger = LoggerProviderSdk(logRecordProcessors: [processor])
            .loggerBuilder(instrumentationScopeName: "test").build()

        // If children ran inline, this call would block for `BlockingLogProcessor`'s guard
        // timeout and the log would already have been received.
        logger.logRecordBuilder().setBody(.string("first")).emit()

        // The first log is still held by the child processor, so the emit returned without it.
        XCTAssertEqual(blockingProcessor.entered.wait(timeout: .now() + TimeInterval.defaultTimeout), .success)
        XCTAssertTrue(blockingProcessor.receivedBodies.isEmpty)
        XCTAssertTrue(childExporter.exportedLogs.isEmpty)

        // The delegate (Embrace's own handling) is still notified on the emitting thread.
        logger.logRecordBuilder().setBody(.string("second")).emit()
        XCTAssertEqual(mockDelegate.emittedLogs.count, 2)

        blockingProcessor.gate.signal()
        processor.waitForAllWork()

        XCTAssertEqual(blockingProcessor.receivedBodies, ["first", "second"])
        XCTAssertEqual(childExporter.exportedLogs.count, 2)
    }

    func test_onEmit_forwardsLogsToChildrenInOrder() {
        let childExporter = CapturingLogExporter()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childExporters: [childExporter])
        let logger = LoggerProviderSdk(logRecordProcessors: [processor])
            .loggerBuilder(instrumentationScopeName: "test").build()

        for i in 0..<50 {
            logger.logRecordBuilder().setBody(.string("\(i)")).emit()
        }
        processor.waitForAllWork()

        XCTAssertEqual(childExporter.exportedLogs.map(\.body), (0..<50).map { .string("\($0)") })
    }

    func test_onEmit_waitsForCriticalResourceGroupBeforeForwardingToChildren() {
        let childExporter = CapturingLogExporter()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childExporters: [childExporter])
        let group = DispatchGroup()
        group.enter()
        processor.criticalResourceGroup = group
        let logger = LoggerProviderSdk(logRecordProcessors: [processor])
            .loggerBuilder(instrumentationScopeName: "test").build()

        logger.logRecordBuilder().setBody(.string("early")).emit()

        // The delegate still hears about the log straight away; only children are gated.
        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)

        // Queue a marker behind the gated job: it can only run once the group is left.
        let drained = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            processor.waitForAllWork()
            drained.signal()
        }
        // timed-wait: window for something that must not happen; the queue must stay blocked while the group is entered.
        XCTAssertEqual(drained.wait(timeout: .now() + 0.5), .timedOut)
        XCTAssertTrue(childExporter.exportedLogs.isEmpty)

        group.leave()
        XCTAssertEqual(drained.wait(timeout: .now() + TimeInterval.defaultTimeout), .success)
        XCTAssertEqual(childExporter.exportedLogs.count, 1)
    }

    func test_onEmit_childrenReceiveAttributesInjectedWhenTheLogWasEmitted() {
        let childProcessor = CapturingLogProcessor()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let group = DispatchGroup()
        group.enter()
        processor.criticalResourceGroup = group
        let logger = LoggerProviderSdk(logRecordProcessors: [processor])
            .loggerBuilder(instrumentationScopeName: "test").build()

        mockDelegate.currentSessionId = EmbraceIdentifier(stringValue: "part-A")
        mockDelegate.currentUserSessionId = EmbraceIdentifier(stringValue: "user-A")
        logger.logRecordBuilder().setBody(.string("external-log")).emit()

        // The session changes while the log is still queued for the children.
        mockDelegate.currentSessionId = EmbraceIdentifier(stringValue: "part-B")
        mockDelegate.currentUserSessionId = EmbraceIdentifier(stringValue: "user-B")
        group.leave()
        processor.waitForAllWork()

        let log = childProcessor.capturedLogs.first
        XCTAssertEqual(log?.attributes[LogSemantics.keyEmbraceType], .string(EmbraceType.message.rawValue))
        XCTAssertEqual(log?.attributes[LogSemantics.keySessionId], .string("user-A"))
        XCTAssertEqual(log?.attributes[LogSemantics.keyUserSessionId], .string("user-A"))
        XCTAssertEqual(log?.attributes[LogSemantics.keyPartId], .string("part-A"))
    }

    // A child exporter that re-enters the SDK queue it was called from (for example by starting a
    // URLSession task, which the network capture handles with `queue.sync`) traps if it runs on that queue.
    func test_onEmit_fromAnSDKQueue_childExporterRunsOffThatQueue() {
        let sdkQueue = DispatchQueue(label: "test.sdk-queue")
        let sdkQueueKey = DispatchSpecificKey<Bool>()
        sdkQueue.setSpecific(key: sdkQueueKey, value: true)

        let childExporter = QueueCheckingLogExporter(key: sdkQueueKey)
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childExporters: [childExporter])
        let logger = LoggerProviderSdk(logRecordProcessors: [processor])
            .loggerBuilder(instrumentationScopeName: "test").build()

        sdkQueue.sync {
            logger.logRecordBuilder().setBody(.string("from-sdk-queue")).emit()
        }
        processor.waitForAllWork()

        XCTAssertEqual(childExporter.ranOnKeyedQueue, [false])
    }

    // MARK: - forceFlush propagation and result aggregation

    func test_forceFlush_runsAfterPendingLogs() {
        let childProcessor = CapturingLogProcessor()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childProcessors: [childProcessor])

        processor.onEmit(logRecord: makeLogRecord(body: "pending"))
        _ = processor.forceFlush(explicitTimeout: 5.0)

        XCTAssertEqual(childProcessor.calls, ["onEmit", "forceFlush"])
    }

    func test_forceFlush_propagatesToChildProcessorsAndExporters() {
        let childProcessor = CapturingLogProcessor()
        let childExporter = CapturingLogExporter()
        let processor = EmbraceLogProcessor(
            delegate: mockDelegate,
            childProcessors: [childProcessor],
            childExporters: [childExporter]
        )

        let result = processor.forceFlush(explicitTimeout: 5.0)

        XCTAssertTrue(childProcessor.didForceFlush)
        XCTAssertTrue(childExporter.didForceFlush)
        XCTAssertEqual(result, .success)
    }

    func test_forceFlush_returnsFailure_whenResultsDiffer() {
        let successProcessor = CapturingLogProcessor()
        successProcessor.forceFlushResult = .success
        let failureExporter = CapturingLogExporter()
        failureExporter.forceFlushResult = .failure
        let processor = EmbraceLogProcessor(
            delegate: mockDelegate,
            childProcessors: [successProcessor],
            childExporters: [failureExporter]
        )

        let result = processor.forceFlush(explicitTimeout: 5.0)

        XCTAssertEqual(result, .failure)
    }

    // MARK: - shutdown propagation

    func test_shutdown_runsAfterPendingLogs() {
        let childProcessor = CapturingLogProcessor()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childProcessors: [childProcessor])

        processor.onEmit(logRecord: makeLogRecord(body: "pending"))
        _ = processor.shutdown(explicitTimeout: 5.0)

        XCTAssertEqual(childProcessor.calls, ["onEmit", "shutdown"])
    }

    func test_shutdown_propagatesToChildProcessorsAndExporters() {
        let childProcessor = CapturingLogProcessor()
        let childExporter = CapturingLogExporter()
        let processor = EmbraceLogProcessor(
            delegate: mockDelegate,
            childProcessors: [childProcessor],
            childExporters: [childExporter]
        )

        _ = processor.shutdown(explicitTimeout: 5.0)

        XCTAssertTrue(childProcessor.didShutdown)
        XCTAssertTrue(childExporter.didShutdown)
    }

    private func makeLogRecord(body: String) -> ReadableLogRecord {
        ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
            timestamp: Date(),
            body: .string(body),
            attributes: [:]
        )
    }
}

// MARK: - Mocks

class MockLogProcessorDelegate: EmbraceLogProcessorDelegate {
    var internalLogBodies: Set<String> = []
    var emittedLogs: [ReadableLogRecord] = []
    var currentSessionState: SessionState = .foreground
    var currentSessionId: EmbraceIdentifier? = nil
    var currentUserSessionId: EmbraceIdentifier? = nil

    func isInternalLog(_ log: ReadableLogRecord) -> Bool {
        guard case let .string(body) = log.body else { return false }
        return internalLogBodies.contains(body)
    }

    func onExternalLogEmitted(_ log: ReadableLogRecord) {
        emittedLogs.append(log)
    }
}

class CapturingLogProcessor: LogRecordProcessor {
    private(set) var capturedLogs: [ReadableLogRecord] = []
    private(set) var calls: [String] = []
    private(set) var didForceFlush = false
    private(set) var didShutdown = false
    var forceFlushResult: ExportResult = .success

    func onEmit(logRecord: ReadableLogRecord) {
        calls.append("onEmit")
        capturedLogs.append(logRecord)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        calls.append("forceFlush")
        didForceFlush = true
        return forceFlushResult
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        calls.append("shutdown")
        didShutdown = true
        return .success
    }
}

/// Blocks inside the first `onEmit` until `gate` is signalled, which holds the processor queue.
private class BlockingLogProcessor: LogRecordProcessor {
    let entered = DispatchSemaphore(value: 0)
    let gate = DispatchSemaphore(value: 0)
    private(set) var receivedBodies: [String] = []

    func onEmit(logRecord: ReadableLogRecord) {
        if receivedBodies.isEmpty {
            entered.signal()
            // timed-wait: deadlock guard so a regression to inline forwarding fails instead of hanging.
            _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        }
        if case let .string(body) = logRecord.body {
            receivedBodies.append(body)
        }
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}

/// Records, for each export, whether it ran on the queue tagged with `key`.
private class QueueCheckingLogExporter: LogRecordExporter {
    private let key: DispatchSpecificKey<Bool>
    private(set) var ranOnKeyedQueue: [Bool] = []

    init(key: DispatchSpecificKey<Bool>) {
        self.key = key
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        ranOnKeyedQueue.append(DispatchQueue.getSpecific(key: key) == true)
        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) {}
}

class CapturingLogExporter: LogRecordExporter {
    private(set) var exportedLogs: [ReadableLogRecord] = []
    private(set) var didForceFlush = false
    private(set) var didShutdown = false
    var forceFlushResult: ExportResult = .success

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        exportedLogs.append(contentsOf: logRecords)
        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        didForceFlush = true
        return forceFlushResult
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }
}
