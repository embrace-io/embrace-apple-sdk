//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorage
import EmbraceOTel

class StorageEmbraceLogExporterTests: XCTestCase {
    private var sut: StorageEmbraceLogExporter!
    private var batcher: SpyLogBatcher!
    private var result: ExportResult!

    func testHavingInactiveLogExporter_onExport_exportShouldFail() {
        givenStorageEmbraceLogExporter(initialState: .inactive)
        whenInvokingExport(withLogs: [randomLogData()])
        thenResult(is: .failure)
    }

    func testHavingActiveLogExporter_onExport_exportShouldAlwaysSucceed() {
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [randomLogData()])
        thenResult(is: .success)
    }

    func testHavingActiveLogExporter_onExportManyLogs_shouldInvokeBatcherForEveryExportedLog() {
        let randomAmount = Int.random(in: 1..<10)
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: randomLogs(quantity: randomAmount))
        thenResult(is: .success)
    }

    func testHavingActiveLogExporter_onShutdown_changesStateToInactive() {
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingShutdown()
        thenState(is: .inactive)
    }

    func test_forceFlush_alwaysSucceedsAsItDoesNothing() {
        givenStorageEmbraceLogExporter()
        whenInvokingForceFlush()
        thenResult(is: .success)
    }
}

private extension StorageEmbraceLogExporterTests {
    func givenStorageEmbraceLogExporter(initialState: StorageEmbraceLogExporter.State = .active) {
        batcher = SpyLogBatcher()
        sut = .init(logBatcher: batcher, state: initialState)
    }

    func whenInvokingExport(withLogs logsData: [ReadableLogRecord]) {
        result = sut.export(logRecords: logsData)
    }

    func whenInvokingShutdown() {
        sut.shutdown()
    }

    func whenInvokingForceFlush() {
        result = sut.forceFlush()
    }

    func thenState(is newState: StorageEmbraceLogExporter.State) {
        XCTAssertEqual(sut.state, newState)
    }

    func thenResult(is exportResult: ExportResult) {
        XCTAssertEqual(result, exportResult)
    }

    func randomLogData() -> ReadableLogRecord {
        ReadableLogRecord(resource: .init(), instrumentationScopeInfo: .init(), timestamp: Date(), attributes: [:])
    }

    func randomLogs(quantity: Int) -> [ReadableLogRecord] {
        (0..<quantity).map { _ in
            randomLogData()
        }
    }
}

class SpyLogBatcher: LogBatcher {
    var didCallAddLogRecord: Bool = false
    var addLogRecordInvocationCount: Int = 0
    var addLogRecordReceivedParameter: LogRecord?
    func addLogRecord(logRecord: LogRecord) {
        didCallAddLogRecord = true
        addLogRecordInvocationCount += 1
        addLogRecordReceivedParameter = logRecord
    }
}
