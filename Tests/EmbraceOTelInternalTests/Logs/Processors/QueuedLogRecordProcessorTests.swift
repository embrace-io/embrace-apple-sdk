//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

class QueuedLogRecordProcessorTests: XCTestCase {

    func test_onEmit_returnsWithoutWaitingForTheWrappedProcessor() throws {
        let processor = BlockingLogRecordProcessor()
        let sut = QueuedLogRecordProcessor(processor: processor)

        // If `onEmit` ran inline, this call would block until the guard timeout below.
        sut.onEmit(logRecord: .log(withTestId: "12345"))

        // The log is still held by the wrapped processor, so `onEmit` returned without it.
        XCTAssertEqual(processor.entered.wait(timeout: .now() + TimeInterval.defaultTimeout), .success)
        XCTAssertFalse(processor.didFinishOnEmit)

        processor.gate.signal()
        _ = sut.forceFlush()

        XCTAssertTrue(processor.didFinishOnEmit)
        XCTAssertFalse(processor.ranOnCallerThread)
        XCTAssertEqual(try processor.receivedLogRecord?.getTestId(), "12345")
    }

    func test_onEmit_forwardsLogsInOrder() throws {
        let processor = RecordingLogRecordProcessor()
        let sut = QueuedLogRecordProcessor(processor: processor)

        for i in 0..<50 {
            sut.onEmit(logRecord: .log(withTestId: "\(i)"))
        }
        _ = sut.forceFlush()

        XCTAssertEqual(try processor.records.map { try $0.getTestId() }, (0..<50).map { "\($0)" })
    }

    func test_forceFlush_runsAfterPendingLogsAndReturnsTheWrappedResult() {
        let processor = RecordingLogRecordProcessor()
        processor.stubbedForceFlushResult = .failure
        let sut = QueuedLogRecordProcessor(processor: processor)

        sut.onEmit(logRecord: .log(withTestId: "12345"))
        let result = sut.forceFlush()

        XCTAssertEqual(result, .failure)
        XCTAssertEqual(processor.calls, ["onEmit", "forceFlush"])
    }

    func test_shutdown_runsAfterPendingLogsAndReturnsTheWrappedResult() {
        let processor = RecordingLogRecordProcessor()
        processor.stubbedShutdownResult = .failure
        let sut = QueuedLogRecordProcessor(processor: processor)

        sut.onEmit(logRecord: .log(withTestId: "12345"))
        let result = sut.shutdown()

        XCTAssertEqual(result, .failure)
        XCTAssertEqual(processor.calls, ["onEmit", "shutdown"])
    }
}

/// Blocks inside `onEmit` until `gate` is signalled.
private class BlockingLogRecordProcessor: LogRecordProcessor {
    let entered = DispatchSemaphore(value: 0)
    let gate = DispatchSemaphore(value: 0)
    private let callerThread = Thread.current

    private(set) var didFinishOnEmit = false
    private(set) var ranOnCallerThread = false
    private(set) var receivedLogRecord: ReadableLogRecord?

    func onEmit(logRecord: ReadableLogRecord) {
        ranOnCallerThread = Thread.current == callerThread
        entered.signal()
        // timed-wait: deadlock guard so a regression to inline forwarding fails instead of hanging.
        _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        receivedLogRecord = logRecord
        didFinishOnEmit = true
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}

private class RecordingLogRecordProcessor: LogRecordProcessor {
    private(set) var calls: [String] = []
    private(set) var records: [ReadableLogRecord] = []
    var stubbedForceFlushResult: ExportResult = .success
    var stubbedShutdownResult: ExportResult = .success

    func onEmit(logRecord: ReadableLogRecord) {
        calls.append("onEmit")
        records.append(logRecord)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        calls.append("forceFlush")
        return stubbedForceFlushResult
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        calls.append("shutdown")
        return stubbedShutdownResult
    }
}
