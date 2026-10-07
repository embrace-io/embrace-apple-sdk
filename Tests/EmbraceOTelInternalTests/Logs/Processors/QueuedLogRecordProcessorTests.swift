//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

class QueuedLogRecordProcessorTests: XCTestCase {

    private let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_onEmit_returnsWithoutWaitingForTheWrappedProcessor() throws {
        let processor = BlockingLogRecordProcessor()
        let sut = queued(processors: [processor])

        // If `onEmit` ran inline, this call would block for `BlockingLogRecordProcessor`'s guard
        // timeout and the log would already have been received.
        sut.onEmit(logRecord: .log(withTestId: "12345"))

        // The log is still held by the wrapped processor, so `onEmit` returned without it.
        XCTAssertEqual(processor.entered.wait(timeout: .now() + TimeInterval.defaultTimeout), .success)
        XCTAssertNil(processor.receivedLogRecord)

        processor.gate.signal()
        _ = sut.forceFlush()

        XCTAssertFalse(processor.ranOnCallerThread)
        XCTAssertEqual(try processor.receivedLogRecord?.getTestId(), "12345")
    }

    func test_onEmit_forwardsLogsInOrder() throws {
        let processor = RecordingLogRecordProcessor()
        let sut = queued(processors: [processor])

        for i in 0..<50 {
            sut.onEmit(logRecord: .log(withTestId: "\(i)"))
        }
        _ = sut.forceFlush()

        XCTAssertEqual(try processor.records.map { try $0.getTestId() }, (0..<50).map { "\($0)" })
    }

    func test_onEmit_whenSDKIsDisabled_dropsTheLog() {
        let processor = RecordingLogRecordProcessor()
        let sut = queued(processors: [processor])
        sdkStateProvider.isEnabled = false

        sut.onEmit(logRecord: .log(withTestId: "12345"))
        _ = sut.forceFlush()

        XCTAssertTrue(processor.records.isEmpty)
    }

    func test_onEmit_whenSDKIsDisabledWhileTheLogIsQueued_stillForwardsTheLog() throws {
        let processor = RecordingLogRecordProcessor()
        let sut = queued(processors: [processor])

        let gate = DispatchSemaphore(value: 0)
        sut.queue.async {
            // timed-wait: bounded so the queue is still released if the test exits before `gate.signal()`.
            _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        }

        sut.onEmit(logRecord: .log(withTestId: "12345"))
        sdkStateProvider.isEnabled = false
        gate.signal()
        _ = sut.forceFlush()

        XCTAssertEqual(try processor.records.map { try $0.getTestId() }, ["12345"])
    }

    func test_forceFlush_runsAfterPendingLogsAndReturnsTheWrappedResult() {
        let processor = RecordingLogRecordProcessor()
        let exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedExportResponse = .success
        exporter.stubbedForceFlushResponse = .failure
        let sut = queued(processors: [processor], exporters: [exporter])

        sut.onEmit(logRecord: .log(withTestId: "12345"))
        let result = sut.forceFlush()

        XCTAssertEqual(result, .failure)
        XCTAssertEqual(processor.calls, ["onEmit", "forceFlush"])
    }

    func test_shutdown_runsAfterPendingLogs() {
        let processor = RecordingLogRecordProcessor()
        let sut = queued(processors: [processor])

        sut.onEmit(logRecord: .log(withTestId: "12345"))
        let result = sut.shutdown()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(processor.calls, ["onEmit", "shutdown"])
    }

    private func queued(
        processors: [LogRecordProcessor] = [],
        exporters: [LogRecordExporter] = []
    ) -> QueuedLogRecordProcessor {
        QueuedLogRecordProcessor(
            processor: SingleLogRecordProcessor(
                processors: processors,
                exporters: exporters,
                sdkStateProvider: sdkStateProvider
            )
        )
    }
}

/// Blocks inside `onEmit` until `gate` is signalled.
private class BlockingLogRecordProcessor: LogRecordProcessor {
    let entered = DispatchSemaphore(value: 0)
    let gate = DispatchSemaphore(value: 0)
    private let callerThread = Thread.current

    private(set) var ranOnCallerThread = false
    private(set) var receivedLogRecord: ReadableLogRecord?

    func onEmit(logRecord: ReadableLogRecord) {
        ranOnCallerThread = Thread.current == callerThread
        entered.signal()
        // timed-wait: deadlock guard so a regression to inline forwarding fails instead of hanging.
        _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        receivedLogRecord = logRecord
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}

private class RecordingLogRecordProcessor: LogRecordProcessor {
    private(set) var calls: [String] = []
    private(set) var records: [ReadableLogRecord] = []

    func onEmit(logRecord: ReadableLogRecord) {
        calls.append("onEmit")
        records.append(logRecord)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        calls.append("forceFlush")
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        calls.append("shutdown")
        return .success
    }
}
