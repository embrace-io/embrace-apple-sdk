//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import Foundation

@testable import EmbraceOTelInternal

class SingleLogRecordProcessorTests: XCTestCase {
    private var sut: SingleLogRecordProcessor!
    private var exporter: SpyEmbraceLogRecordExporter!
    private var result: ExportResult!

    func testHavingAtLeastOneProcessor_onEmit_shouldPassLogRecordToExporterAsAnArray() throws {
        givenProcessorWithAnExporter()
        whenInvokingEmit(withLog: .log(withTestId: "12345"))
        thenExporterInvokesExport()
        thenExporterReceivesOneLog()
        try thenExporterReceivesTheLog(withTestId: "12345")
    }

    func testHavingAtLeastOneProcessor_onShutdown_shouldExecuteShutdownOnExporter() {
        givenProcessorWithAnExporter()
        whenInvokingShutdown()
        thenExporterInvokesShutdown()
    }

    func test_onShutdown_resultIsAlwaysSuccess() {
        givenProcessorWithAnExporter()
        whenInvokingShutdown()
        thenExportResult(is: .success)
    }

    func testHavingAtLeastOneProcessor_onForceFlush_shouldExecuteForceFlushOnExporter() {
        givenProcessorWithAnExporter()
        whenInvokingForceFlush()
        thenExportInvokesForceFlush()
    }

    func testOnHavingMutlipleExportersAndAtLeastOnFailingFlush_onForceFlush_resultIsFailure() {
        givenProcessor(
            withExporters: [
                successfulFlushExporter(),
                failingFlushExporter(),
                successfulFlushExporter(),
                successfulFlushExporter()
            ]
        )
        whenInvokingForceFlush()
        thenExportResult(is: .failure)
    }

    func testOnHavingNoExporters_onForceFlush_resultIsAlwaysSuccess() {
        givenProcessor(withExporters: [])
        whenInvokingForceFlush()
        thenExportResult(is: .success)
    }
}

private extension SingleLogRecordProcessorTests {
    func givenProcessorWithAnExporter() {
        exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedExportResponse = .success
        exporter.stubbedForceFlushResponse = .success
        givenProcessor(withExporters: [exporter])
    }

    func givenProcessor(withExporters exporters: [EmbraceLogRecordExporter]) {
        sut = .init(exporters: exporters)
    }

    func whenInvokingEmit(withLog log: ReadableLogRecord) {
        sut.onEmit(logRecord: log)
    }

    func whenInvokingShutdown() {
        result = sut.shutdown()
    }

    func whenInvokingForceFlush() {
        result = sut.forceFlush()
    }

    func thenExportInvokesForceFlush() {
        XCTAssertTrue(exporter.didCallForceFlush)
    }

    func thenExporterInvokesShutdown() {
        XCTAssertTrue(exporter.didCallShutdown)
    }

    func thenExporterInvokesExport() {
        XCTAssertTrue(exporter.didCallExport)
    }

    func thenExporterReceivesOneLog() {
        XCTAssertEqual(exporter.exportLogRecordsReceivedParameter.count, 1)
    }

    func thenExportResult(is resultValue: ExportResult) {
        XCTAssertEqual(result, resultValue)
    }

    func thenExporterReceivesTheLog(withTestId testId: String) throws {
        let log = try XCTUnwrap(exporter.exportLogRecordsReceivedParameter.first)
        XCTAssertEqual(try log.getTestId(), testId)
    }

    func failingFlushExporter() -> SpyEmbraceLogRecordExporter {
        let exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedForceFlushResponse = .failure
        return exporter
    }

    func successfulFlushExporter() -> SpyEmbraceLogRecordExporter {
        let exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedForceFlushResponse = .success
        return exporter
    }
}
