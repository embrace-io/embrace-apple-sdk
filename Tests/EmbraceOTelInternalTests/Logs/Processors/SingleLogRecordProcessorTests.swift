//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

class SingleLogRecordProcessorTests: XCTestCase {
    private var sut: SingleLogRecordProcessor!
    private var exporter: SpyEmbraceLogRecordExporter!
    private var result: ExportResult!
    private var sdkStateProvider: MockEmbraceSDKStateProvider!

    func test_emit_sdkDisabled() throws {
        givenProcessorWithAnExporter()
        givenDisabledSDK()
        whenInvokingEmit(withLog: .log(withTestId: "12345"))
        thenExportDoesNotInvokeExport()
        thenExporterReceivesNoLogs()
    }

    func test_forceFlush_sdkDisabled() throws {
        givenProcessorWithAnExporter()
        givenDisabledSDK()
        whenInvokingForceFlush()
        thenExportDoesNotInvokeForceFlush()
        thenExporterReceivesNoLogs()
    }

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

extension SingleLogRecordProcessorTests {
    fileprivate func givenProcessorWithAnExporter() {
        exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedExportResponse = .success
        exporter.stubbedForceFlushResponse = .success
        givenProcessor(withExporters: [exporter])
    }

    fileprivate func givenProcessor(withExporters exporters: [LogRecordExporter]) {
        sdkStateProvider = MockEmbraceSDKStateProvider()
        sut = .init(exporters: exporters, sdkStateProvider: sdkStateProvider)
    }

    fileprivate func givenDisabledSDK() {
        sdkStateProvider.isEnabled = false
    }

    fileprivate func whenInvokingEmit(withLog log: ReadableLogRecord) {
        sut.onEmit(logRecord: log)
    }

    fileprivate func whenInvokingShutdown() {
        result = sut.shutdown()
    }

    fileprivate func whenInvokingForceFlush() {
        result = sut.forceFlush()
    }

    fileprivate func thenExportInvokesForceFlush() {
        XCTAssertTrue(exporter.didCallForceFlush)
    }

    fileprivate func thenExporterInvokesShutdown() {
        XCTAssertTrue(exporter.didCallShutdown)
    }

    fileprivate func thenExporterInvokesExport() {
        XCTAssertTrue(exporter.didCallExport)
    }

    fileprivate func thenExportDoesNotInvokeExport() {
        XCTAssertFalse(exporter.didCallExport)
    }

    fileprivate func thenExportDoesNotInvokeForceFlush() {
        XCTAssertFalse(exporter.didCallForceFlush)
    }

    fileprivate func thenExporterReceivesOneLog() {
        XCTAssertEqual(exporter.exportLogRecordsReceivedParameter.count, 1)
    }

    fileprivate func thenExporterReceivesNoLogs() {
        XCTAssertEqual(exporter.exportLogRecordsReceivedParameter.count, 0)
    }

    fileprivate func thenExportResult(is resultValue: ExportResult) {
        XCTAssertEqual(result, resultValue)
    }

    fileprivate func thenExporterReceivesTheLog(withTestId testId: String) throws {
        let log = try XCTUnwrap(exporter.exportLogRecordsReceivedParameter.first)
        XCTAssertEqual(try log.getTestId(), testId)
    }

    fileprivate func failingFlushExporter() -> SpyEmbraceLogRecordExporter {
        let exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedForceFlushResponse = .failure
        return exporter
    }

    fileprivate func successfulFlushExporter() -> SpyEmbraceLogRecordExporter {
        let exporter = SpyEmbraceLogRecordExporter()
        exporter.stubbedForceFlushResponse = .success
        return exporter
    }
}
