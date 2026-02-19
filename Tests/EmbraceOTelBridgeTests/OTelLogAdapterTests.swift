//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceOTelBridge

final class OTelLogAdapterTests: XCTestCase {

    var loggerProvider: LoggerProviderSdk!
    var capturingProcessor: LogCapturingProcessor!
    var otelLogger: Logger!
    var mockMetadataProvider: MockMetadataProvider!

    override func setUp() {
        super.setUp()
        capturingProcessor = LogCapturingProcessor()
        loggerProvider = LoggerProviderSdk(logRecordProcessors: [capturingProcessor])
        otelLogger = loggerProvider.loggerBuilder(instrumentationScopeName: "test").build()
        mockMetadataProvider = MockMetadataProvider()
    }

    private func emitLog(
        body: String = "test message",
        severity: Severity = .info,
        attributes: [String: AttributeValue] = [:]
    ) -> ReadableLogRecord? {
        var builder = otelLogger.logRecordBuilder()
        builder = builder.setBody(.string(body))
        builder = builder.setSeverity(severity)
        if !attributes.isEmpty {
            builder = builder.setAttributes(attributes)
        }
        builder.emit()
        return capturingProcessor.capturedLogs.last
    }

    func test_id_generatedWhenNotInAttributes() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertFalse(adapter.id.isEmpty)
    }

    func test_severity_mapsInfoCorrectly() {
        guard let record = emitLog(severity: .info) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.severity, .info)
    }

    func test_severity_mapsErrorCorrectly() {
        guard let record = emitLog(severity: .error) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.severity, .error)
    }

    func test_severity_mapsWarnCorrectly() {
        guard let record = emitLog(severity: .warn) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.severity, .warn)
    }

    func test_severity_defaultsToInfoForUnknownSeverity() {
        // trace2 (rawValue 2) has no matching EmbraceLogSeverity case, so should default to .info
        guard let record = emitLog(severity: .trace2) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.severity, .info)
    }

    func test_body_mapsCorrectly() {
        guard let record = emitLog(body: "hello world") else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.body, "hello world")
    }

    func test_attributes_areMapped() {
        guard let record = emitLog(attributes: ["key": .string("value")]) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["key"] as? String, "value")
    }

    func test_type_defaultsToMessageWhenNotSet() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.type, .message)
    }

    func test_sessionId_comesFromMetadataProvider() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.sessionId, mockMetadataProvider.currentSessionId)
    }

    func test_processId_comesFromMetadataProvider() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.processId, mockMetadataProvider.currentProcessId)
    }

    func test_timestamp_isSet() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertNotNil(adapter.timestamp)
    }
}
