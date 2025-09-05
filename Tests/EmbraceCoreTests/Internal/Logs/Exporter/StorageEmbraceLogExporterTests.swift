//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceOTelInternal
import EmbraceSemantics
import EmbraceStorageInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceCore

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
        let logData = randomLogData(
            body: "example",
            attributes: [
                "foo": .string("bar"),
                "age": .int(42),
                "grade": .double(96.7),
                "alive": .bool(true)
            ])

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [logData])
        thenBatchAdded(count: 1)
        thenResult(is: .success)

        thenRecordMatches(
            record: batcher.logRecords.last!, body: "example",
            attributes: [
                "foo": .string("bar"),
                "age": .int(42),
                "grade": .double(96.7),
                "alive": .bool(true)
            ])
    }

    func test_havingActiveLogExporter_onExport_whenInvalidBody_exportSucceedsButNotAddedToBatch() {
        givenStorageEmbraceLogExporter(initialState: .active)

        var str = ""
        for _ in 1...4001 {
            str += "."
        }
        whenInvokingExport(withLogs: [randomLogData(body: str)])

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

        var str = ""
        for _ in 1...4001 {
            str += "."
        }
        let invalidLogs = randomLogs(quantity: Int.random(in: 1..<10), body: str)

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
            attributes: ["emb.type": .string(EmbraceType.crash.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [logData])
        thenBatchAdded(count: 0)
        thenResult(is: .success)
    }

    func test_rawCrashLogs_fromMetrickKit_getsExported() {
        let logData = randomLogData(
            body: "example",
            attributes: [
                "emb.type": .string(EmbraceType.crash.rawValue),
                "emb.provider": .string("metrickit")
            ]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        whenInvokingExport(withLogs: [logData])
        thenBatchAdded(count: 1)
        thenResult(is: .success)
    }

    // MARK: Limits
    func test_limits_ignored() {
        let internalLog = randomLogData(
            body: "example",
            attributes: ["emb.type": .string(EmbraceType.internal.rawValue)]
        )

        let metricKitCrash = randomLogData(
            body: "example",
            attributes: [
                "emb.type": .string(EmbraceType.crash.rawValue),
                "emb.provider": .string("metrickit")
            ]
        )

        let metricKitHang = randomLogData(
            body: "example",
            attributes: [
                "emb.type": .string(EmbraceType.hang.rawValue),
                "emb.provider": .string("metrickit")
            ]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 0, warning: 0, error: 0))
        whenInvokingExport(withLogs: [internalLog, metricKitCrash, metricKitHang])
        thenBatchAdded(count: 3)
        thenResult(is: .success)
    }

    func test_limits_empty() {
        let info = randomLogData(
            body: "example",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let warning = randomLogData(
            body: "example",
            severity: Severity.warn,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let error = randomLogData(
            body: "example",
            severity: Severity.error,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 0, warning: 0, error: 0))
        whenInvokingExport(withLogs: [info, warning, error])
        thenBatchAdded(count: 0)
        thenResult(is: .success)
    }

    func test_limits_info() {
        let info = randomLogData(
            body: "example",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let warning = randomLogData(
            body: "example",
            severity: Severity.warn,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let error = randomLogData(
            body: "example",
            severity: Severity.error,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 1, warning: 0, error: 0))
        whenInvokingExport(withLogs: [info, warning, error])
        thenBatchAdded(count: 1)
        thenResult(is: .success)
    }

    func test_limits_warning() {
        let info = randomLogData(
            body: "example",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let warning = randomLogData(
            body: "example",
            severity: Severity.warn,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let error = randomLogData(
            body: "example",
            severity: Severity.error,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 0, warning: 1, error: 0))
        whenInvokingExport(withLogs: [info, warning, error])
        thenBatchAdded(count: 1)
        thenResult(is: .success)
    }

    func test_limits_error() {
        let info = randomLogData(
            body: "example",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let warning = randomLogData(
            body: "example",
            severity: Severity.warn,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let error = randomLogData(
            body: "example",
            severity: Severity.error,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 0, warning: 0, error: 1))
        whenInvokingExport(withLogs: [info, warning, error])
        thenBatchAdded(count: 1)
        thenResult(is: .success)
    }

    func test_limit_reached() {
        let info1 = randomLogData(
            body: "example1",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let info2 = randomLogData(
            body: "example2",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 1, warning: 0, error: 0))
        whenInvokingExport(withLogs: [info1])
        thenBatchAdded(count: 1)
        thenResult(is: .success)

        whenInvokingExport(withLogs: [info2])
        thenBatchAdded(count: 1)  // count still 1
        thenResult(is: .success)
    }

    func test_limit_reset() {
        let info1 = randomLogData(
            body: "example1",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        let info2 = randomLogData(
            body: "example2",
            severity: Severity.info,
            attributes: ["emb.type": .string(EmbraceType.breadcrumb.rawValue)]
        )

        givenStorageEmbraceLogExporter(initialState: .active)
        givenLogsLimits(LogsLimits(info: 1, warning: 0, error: 0))
        whenInvokingExport(withLogs: [info1])
        thenBatchAdded(count: 1)
        thenResult(is: .success)

        whenANewSessionStarts()

        whenInvokingExport(withLogs: [info2])
        thenBatchAdded(count: 2)
        thenResult(is: .success)
    }
}

extension StorageEmbraceLogExporterTests {
    fileprivate func givenStorageEmbraceLogExporter(initialState: StorageEmbraceLogExporter.State = .active) {
        batcher = SpyLogBatcher()
        sut = .init(logBatcher: batcher, state: initialState)
    }

    fileprivate func givenLogsLimits(_ limits: LogsLimits) {
        batcher.limits = limits
    }

    fileprivate func whenInvokingExport(withLogs logsData: [ReadableLogRecord]) {
        result = sut.export(logRecords: logsData)
    }

    fileprivate func whenInvokingShutdown() {
        sut.shutdown()
    }

    fileprivate func whenInvokingForceFlush() {
        result = sut.forceFlush()
    }

    fileprivate func whenANewSessionStarts() {
        NotificationCenter.default.post(name: .embraceSessionDidStart, object: nil)
    }

    fileprivate func thenState(is newState: StorageEmbraceLogExporter.State) {
        XCTAssertEqual(sut.state, newState)
    }

    fileprivate func thenResult(is exportResult: ExportResult) {
        XCTAssertEqual(result, exportResult)
    }

    fileprivate func thenBatchAdded(count logCount: Int) {
        XCTAssertEqual(batcher.addLogRecordInvocationCount, logCount)
    }

    fileprivate func thenRecordMatches(record: ReadableLogRecord, body: String, attributes: [String: AttributeValue]) {
        XCTAssertEqual(record.body!.description, body)
        XCTAssertEqual(record.attributes, attributes)
    }

    fileprivate func randomLogData(
        body: String? = nil, severity: Severity? = nil, attributes: [String: AttributeValue] = [:]
    ) -> ReadableLogRecord {
        ReadableLogRecord(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: Date(),
            severity: severity,
            body: .string(body ?? ""),
            attributes: attributes)
    }

    fileprivate func randomLogs(quantity: Int, body: String? = nil) -> [ReadableLogRecord] {
        (0..<quantity).map { _ in
            randomLogData(body: body)
        }
    }
}

class SpyLogBatcher: LogBatcher {
    private(set) var didCallAddLogRecord: Bool = false
    private(set) var addLogRecordInvocationCount: Int = 0
    private(set) var logRecords = [ReadableLogRecord]()

    func addLogRecord(logRecord: ReadableLogRecord) {
        didCallAddLogRecord = true
        addLogRecordInvocationCount += 1
        logRecords.append(logRecord)
    }

    private(set) var didCallForceEndCurrentBatch: Bool = false
    private(set) var forceEndCurrentBatchParameters: (Bool)?
    func forceEndCurrentBatch(waitUntilFinished: Bool) {
        forceEndCurrentBatchParameters = (waitUntilFinished)
        didCallForceEndCurrentBatch = true
        self.renewBatch(withLogs: [])
    }

    private(set) var didCallRenewBatch: Bool = false
    private(set) var renewBatchInvocationCount: Int = 0
    func renewBatch(withLogs logs: [EmbraceLog]) {
        didCallRenewBatch = true
        renewBatchInvocationCount += 1
    }

    var limits = LogsLimits()
}
