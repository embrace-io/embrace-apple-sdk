//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
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
        mockDelegate.currentSessionId = EmbraceIdentifier(stringValue: "log-session-123")

        emitLog(body: "external-log")

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        let log = mockDelegate.emittedLogs.first
        XCTAssertEqual(log?.attributes[LogSemantics.keyEmbraceType], .string(EmbraceType.message.rawValue))
        XCTAssertEqual(log?.attributes[LogSemantics.keyState], .string("background"))
        XCTAssertEqual(log?.attributes[LogSemantics.keySessionId], .string("log-session-123"))
    }

    // MARK: - Child processor forwarding

    func test_onEmit_forwardsToChildProcessors() {
        let childProcessor = CapturingLogProcessor()
        let processor = EmbraceLogProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let provider = LoggerProviderSdk(logRecordProcessors: [processor])
        let logger = provider.loggerBuilder(instrumentationScopeName: "test").build()

        logger.logRecordBuilder().setBody(.string("forwarded")).setSeverity(.info).emit()

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

        XCTAssertEqual(childExporter.exportedLogs.count, 1)
    }

    // MARK: - forceFlush propagation and result aggregation

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
}

// MARK: - Mocks

class MockLogProcessorDelegate: EmbraceLogProcessorDelegate {
    var internalLogBodies: Set<String> = []
    var emittedLogs: [ReadableLogRecord] = []
    var currentSessionState: SessionState = .foreground
    var currentSessionId: EmbraceIdentifier? = nil

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
    private(set) var didForceFlush = false
    private(set) var didShutdown = false
    var forceFlushResult: ExportResult = .success

    func onEmit(logRecord: ReadableLogRecord) {
        capturedLogs.append(logRecord)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        didForceFlush = true
        return forceFlushResult
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        didShutdown = true
        return .success
    }
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
