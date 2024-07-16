//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorageInternal
import EmbraceOTelInternal
import EmbraceCommonInternal

class StorageEmbraceLogExporterTests: XCTestCase {
    private var sut: StorageEmbraceLogExporter!
    private var batcher: SpyLogBatcher!
    private var result: ExportResult!

    func test_havingInactiveLogExporter_onExport_exportShouldFail() {
        givenStorageEmbraceLogExporter(initialState: .inactive)
        whenInvokingExport(withLogs: [randomLogData()])
        thenBatchAdded(count: 0)
        thenResult(is: .failure)
    }

    func test_havingActiveLogExporter_onExport_exportSucceeds() {
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [randomLogData(body: "example")])
        thenBatchAdded(count: 1)
        thenResult(is: .success)
    }

    func test_havingActiveLogExporter_onExport_withAttributes_exportSucceeds() {
        let logData = randomLogData(body: "example", attributes: ["foo": .string("bar")])

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [logData])
        thenBatchAdded(count: 1)
        thenResult(is: .success)
    }

    func test_havingActiveLogExporter_onExport_withAttributesOfAllTypes_exportSucceeds() {
        let logData = randomLogData(body: "example", attributes: [
            "foo": .string("bar"),
            "age": .int(42),
            "grade": .double(96.7),
            "alive": .bool(true)
        ])

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [logData])
        thenBatchAdded(count: 1)
        thenResult(is: .success)

        thenRecordMatches(record: batcher.logRecords.last!, body: "example", attributes: [
            "foo": .string("bar"),
            "age": .int(42),
            "grade": .double(96.7),
            "alive": .bool(true)
        ])
    }

    func test_havingActiveLogExporter_onExport_whenInvalidBody_exportSucceedsButNotAddedToBatch() {
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [randomLogData(body: nil)])
        thenBatchAdded(count: 0)
        thenResult(is: .success)
    }

    func test_havingActiveLogExporter_onExportManyLogs_shouldInvokeBatcherForEveryExportedLog() {
        let randomAmount = Int.random(in: 1..<10)
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: randomLogs(quantity: randomAmount, body: "example"))
        thenBatchAdded(count: randomAmount)
        thenResult(is: .success)
    }

    func test_havingActiveLogExporter_onExportManyLogs_someValidSomeInvalid_shouldInvokeBatcherForEveryValidLog() {
        let validAmount = Int.random(in: 1..<10)
        let validLogs = randomLogs(quantity: validAmount, body: "example")
        let invalidLogs = randomLogs(quantity: Int.random(in: 1..<10))

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: (validLogs + invalidLogs).shuffled())
        thenBatchAdded(count: validAmount)
        thenResult(is: .success)
    }

    func test_havingActiveLogExporter_onShutdown_changesStateToInactive() {
        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingShutdown()
        thenState(is: .inactive)
    }

    func test_forceFlush_alwaysSucceedsAsItDoesNothing() {
        givenStorageEmbraceLogExporter()
        whenInvokingForceFlush()
        thenResult(is: .success)
    }

    func test_rawCrashLogs_dontGetExported() {
        let logData = randomLogData(
            body: "example",
            attributes: [ "emb.type": .string(LogType.crash.rawValue) ]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [logData])
        thenBatchAdded(count: 0)
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

    func thenBatchAdded(count logCount: Int) {
        XCTAssertEqual(batcher.addLogRecordInvocationCount, logCount)
    }

    func thenRecordMatches(record: LogRecord, body: String, attributes: [String: PersistableValue]) {
        XCTAssertEqual(record.body, body)
        XCTAssertEqual(record.attributes, attributes)
    }

    func randomLogData(body: String? = nil, attributes: [String: AttributeValue] = [:]) -> ReadableLogRecord {
        ReadableLogRecord(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: Date(),
            body: body,
            attributes: attributes )
    }

    func randomLogs(quantity: Int, body: String? = nil) -> [ReadableLogRecord] {
        (0..<quantity).map { _ in
            randomLogData(body: body)
        }
    }
}

class SpyLogBatcher: LogBatcher {
    private (set) var didCallAddLogRecord: Bool = false
    private (set) var addLogRecordInvocationCount: Int = 0
    private (set) var logRecords = [LogRecord]()

    func addLogRecord(logRecord: LogRecord) {
        didCallAddLogRecord = true
        addLogRecordInvocationCount += 1
        logRecords.append(logRecord)
    }
}
