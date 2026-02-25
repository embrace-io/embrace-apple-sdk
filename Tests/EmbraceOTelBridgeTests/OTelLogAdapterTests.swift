//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
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

    // MARK: - id when LogSemantics.keyId is present

    func test_id_usesExistingIdFromAttributes() {
        guard let record = emitLog(attributes: [LogSemantics.keyId: .string("custom-log-id")]) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.id, "custom-log-id")
    }

    // MARK: - type when emb.type attribute is set

    func test_type_mapsFromEmbraceTypeAttribute() {
        guard let record = emitLog(attributes: [LogSemantics.keyEmbraceType: .string(EmbraceType.exception.rawValue)]) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.type, .exception)
    }

    // MARK: - body when not a string

    func test_body_returnsEmptyString_whenBodyIsNotString() {
        // Emit a log with no body set — the body will be nil / not a string
        var builder = otelLogger.logRecordBuilder()
        builder = builder.setSeverity(.info)
        builder.emit()

        guard let record = capturingProcessor.capturedLogs.last else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.body, "")
    }

    // MARK: - severity when nil

    func test_severity_defaultsToInfo_whenSeverityIsNil() {
        // Emit a log without setting severity
        otelLogger.logRecordBuilder()
            .setBody(.string("no-severity"))
            .emit()

        guard let record = capturingProcessor.capturedLogs.last else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.severity, .info)
    }

    // MARK: - processId fallback when metadataProvider is nil

    func test_processId_fallsBackToProcessIdentifierCurrent_whenProviderIsNil() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: nil)
        XCTAssertEqual(adapter.processId, ProcessIdentifier.current)
    }

    // MARK: - sessionId when metadataProvider is nil

    func test_sessionId_isNil_whenMetadataProviderIsNil() {
        guard let record = emitLog() else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: nil)
        XCTAssertNil(adapter.sessionId)
    }

    // MARK: - Double/Bool/Int attribute mapping

    func test_attributes_mapDoubleCorrectly() {
        guard let record = emitLog(attributes: ["temp": .double(98.6)]) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["temp"] as? Double, 98.6)
    }

    func test_attributes_mapBoolCorrectly() {
        guard let record = emitLog(attributes: ["flag": .bool(true)]) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["flag"] as? Bool, true)
    }

    func test_attributes_mapIntCorrectly() {
        guard let record = emitLog(attributes: ["count": .int(42)]) else {
            XCTFail("No log captured")
            return
        }
        let adapter = OTelLogAdapter(logRecord: record, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["count"] as? Int, 42)
    }
}
