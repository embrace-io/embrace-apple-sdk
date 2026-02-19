//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceOTelBridge

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
}

// MARK: - Mock

class MockLogProcessorDelegate: EmbraceLogProcessorDelegate {
    var internalLogBodies: Set<String> = []
    var emittedLogs: [ReadableLogRecord] = []

    func isInternalLog(_ log: ReadableLogRecord) -> Bool {
        guard case let .string(body) = log.body else { return false }
        return internalLogBodies.contains(body)
    }

    func onExternalLogEmitted(_ log: ReadableLogRecord) {
        emittedLogs.append(log)
    }
}
