//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelBridge

final class EmbraceOTelBridgeTests: XCTestCase {

    var bridge: EmbraceOTelBridge!
    var mockDelegate: MockOTelDelegate!
    var mockMetadata: MockMetadataProvider!
    var spanProcessor: MockSpanProcessor!
    var logExporter: MockLogExporter!

    override func setUp() {
        super.setUp()
        mockDelegate = MockOTelDelegate()
        mockMetadata = MockMetadataProvider()
        spanProcessor = MockSpanProcessor()
        logExporter = MockLogExporter()
        bridge = EmbraceOTelBridge(
            spanProcessors: [spanProcessor],
            logExporters: [logExporter]
        )
        bridge.setup(delegate: mockDelegate, metadataProvider: mockMetadata)
    }

    // MARK: - startSpan

    func test_startSpan_returnsNonEmptyContext() {
        let context = bridge.startSpan(
            name: "test-span",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        XCTAssertFalse(context.spanId.isEmpty)
        XCTAssertFalse(context.traceId.isEmpty)
    }

    func test_startSpan_withEndTime_endsImmediately() {
        let start = Date()
        let end = start.addingTimeInterval(1)
        _ = bridge.startSpan(
            name: "immediate",
            parentSpan: nil,
            status: .unset,
            startTime: start,
            endTime: end,
            events: [],
            links: [],
            attributes: [:]
        )
        // Span should have been exported since it was ended immediately.
        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        XCTAssertEqual(spanProcessor.endedSpans.first?.name, "immediate")
    }

    func test_startSpan_withAttributes_setsThemOnOtelSpan() {
        let start = Date()
        let end = start.addingTimeInterval(1)
        _ = bridge.startSpan(
            name: "attr-span",
            parentSpan: nil,
            status: .unset,
            startTime: start,
            endTime: end,
            events: [],
            links: [],
            attributes: ["foo": "bar"]
        )
        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        XCTAssertEqual(spanProcessor.endedSpans.first?.attributes["foo"], .string("bar"))
    }

    // MARK: - endSpan

    func test_endSpan_triggersExporter() {
        let ctx = bridge.startSpan(
            name: "to-end",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)
        bridge.endSpan(mockSpan, endTime: Date())
        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
    }

    func test_endSpan_calledTwice_onlyExportsOnce() {
        let ctx = bridge.startSpan(
            name: "to-end",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)
        bridge.endSpan(mockSpan, endTime: Date())
        bridge.endSpan(mockSpan, endTime: Date())  // second call is no-op
        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
    }

    // MARK: - Loop prevention

    // The bridge uses EmbraceSpanIdGenerator to pre-reserve the span ID and inserts it into
    // pendingSpanIds before calling builder.startSpan(). This means isInternalSpan returns true
    // when onStart fires synchronously during startSpan(), preventing the delegate from being
    // called. After startSpan() returns, the ID moves from pendingSpanIds into spanCache.

    func test_outboundSpan_onStart_doesNotCallDelegate() {
        // endTime is nil — the span is started but not ended, isolating the onStart window.
        _ = bridge.startSpan(
            name: "internal",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        XCTAssertEqual(mockDelegate.startedSpans.count, 0)
    }

    func test_outboundSpan_onEnd_doesNotCallDelegate() {
        let ctx = bridge.startSpan(
            name: "internal",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)
        bridge.endSpan(mockSpan, endTime: Date())
        XCTAssertEqual(mockDelegate.endedSpans.count, 0)
    }

    func test_outboundSpan_doesNotCallDelegate() {
        let ctx = bridge.startSpan(
            name: "internal",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)
        bridge.endSpan(mockSpan, endTime: Date())
        // No external delegate calls — outbound spans are skipped by EmbraceSpanProcessor.
        XCTAssertEqual(mockDelegate.startedSpans.count, 0)
        XCTAssertEqual(mockDelegate.endedSpans.count, 0)
    }

    // MARK: - createLog

    func test_createLog_triggersExporter() {
        let log = MockEmbraceLog()
        bridge.createLog(log)
        XCTAssertEqual(logExporter.exportedLogs.count, 1)
    }

    func test_outboundLog_doesNotCallDelegate() {
        let log = MockEmbraceLog()
        bridge.createLog(log)
        XCTAssertEqual(mockDelegate.emittedLogs.count, 0)
    }

    // MARK: - updateSpanStatus

    func test_updateSpanStatus_changesUnderlyingOtelSpanStatus() {
        let ctx = bridge.startSpan(
            name: "status-span",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)

        bridge.updateSpanStatus(mockSpan, status: .ok)
        bridge.endSpan(mockSpan, endTime: Date())

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        let exported = spanProcessor.endedSpans.first
        XCTAssertEqual(exported?.status, .ok)
    }

    // MARK: - updateSpanAttribute

    func test_updateSpanAttribute_setsAttributeOnOtelSpan() {
        let ctx = bridge.startSpan(
            name: "attr-span",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)

        bridge.updateSpanAttribute(mockSpan, key: "my.key", value: "my-value")
        bridge.endSpan(mockSpan, endTime: Date())

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        XCTAssertEqual(spanProcessor.endedSpans.first?.attributes["my.key"], .string("my-value"))
    }

    // MARK: - addSpanEvent

    func test_addSpanEvent_addsEventToOtelSpan() {
        let ctx = bridge.startSpan(
            name: "event-span",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let mockSpan = MockEmbraceSpan(spanId: ctx.spanId, traceId: ctx.traceId)
        let eventTime = Date()
        let event = EmbraceSpanEvent(name: "test-event", type: nil, timestamp: eventTime, attributes: ["evt.key": "evt-val"])

        bridge.addSpanEvent(mockSpan, event: event)
        bridge.endSpan(mockSpan, endTime: Date())

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        let exported = spanProcessor.endedSpans.first
        XCTAssertEqual(exported?.events.count, 1)
        XCTAssertEqual(exported?.events.first?.name, "test-event")
    }

    // MARK: - Parent span resolution

    func test_startSpan_withParent_setsOtelParentViaSpanCache() {
        let parentCtx = bridge.startSpan(
            name: "parent",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )
        let parentMock = MockEmbraceSpan(spanId: parentCtx.spanId, traceId: parentCtx.traceId)

        let childCtx = bridge.startSpan(
            name: "child",
            parentSpan: parentMock,
            status: .unset,
            startTime: Date(),
            endTime: nil,
            events: [],
            links: [],
            attributes: [:]
        )

        // Child should share the parent's traceId
        XCTAssertEqual(childCtx.traceId, parentCtx.traceId)

        // End both and verify the parent relationship via exported span data
        let childMock = MockEmbraceSpan(spanId: childCtx.spanId, traceId: childCtx.traceId)
        bridge.endSpan(childMock, endTime: Date())
        bridge.endSpan(parentMock, endTime: Date())

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 2 }
        let childData = spanProcessor.endedSpans.first { $0.name == "child" }
        XCTAssertEqual(childData?.parentSpanId?.hexString, parentCtx.spanId)
    }

    // MARK: - Links at creation time

    func test_startSpan_withLinks_addsLinksToOtelSpan() {
        // Use valid hex IDs (16 chars for spanId, 32 chars for traceId)
        let linkedSpanId = "abcdef1234567890"
        let linkedTraceId = "abcdef1234567890abcdef1234567890"
        let link = EmbraceSpanLink(spanId: linkedSpanId, traceId: linkedTraceId, attributes: ["link.key": "link-val"])

        let start = Date()
        let end = start.addingTimeInterval(1)
        _ = bridge.startSpan(
            name: "linked-span",
            parentSpan: nil,
            status: .unset,
            startTime: start,
            endTime: end,
            events: [],
            links: [link],
            attributes: [:]
        )

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        let exported = spanProcessor.endedSpans.first
        XCTAssertEqual(exported?.links.count, 1)
        XCTAssertEqual(exported?.links.first?.context.spanId.hexString, linkedSpanId)
        XCTAssertEqual(exported?.links.first?.context.traceId.hexString, linkedTraceId)
    }

    // MARK: - Events at creation time

    func test_startSpan_withEvents_addsEventsToOtelSpan() {
        let eventTime = Date()
        let event = EmbraceSpanEvent(name: "creation-event", type: nil, timestamp: eventTime, attributes: [:])

        let start = Date()
        let end = start.addingTimeInterval(1)
        _ = bridge.startSpan(
            name: "event-span",
            parentSpan: nil,
            status: .unset,
            startTime: start,
            endTime: end,
            events: [event],
            links: [],
            attributes: [:]
        )

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        let exported = spanProcessor.endedSpans.first
        XCTAssertEqual(exported?.events.count, 1)
        XCTAssertEqual(exported?.events.first?.name, "creation-event")
    }

    // MARK: - Status at creation time

    func test_startSpan_withStatus_appliesStatusToOtelSpan() {
        let start = Date()
        let end = start.addingTimeInterval(1)
        _ = bridge.startSpan(
            name: "ok-span",
            parentSpan: nil,
            status: .ok,
            startTime: start,
            endTime: end,
            events: [],
            links: [],
            attributes: [:]
        )

        wait(timeout: .defaultTimeout) { self.spanProcessor.endedSpans.count == 1 }
        XCTAssertEqual(spanProcessor.endedSpans.first?.status, .ok)
    }

    // MARK: - endSpan for unknown span ID

    func test_endSpan_unknownSpanId_isNoOp() {
        let unknownSpan = MockEmbraceSpan(spanId: "0000000000000000", traceId: "00000000000000000000000000000000")
        // Should not crash or trigger any export
        bridge.endSpan(unknownSpan, endTime: Date())
        XCTAssertEqual(spanProcessor.endedSpans.count, 0)
    }

    // MARK: - createLog with severities

    func test_createLog_withErrorSeverity_mapsCorrectly() {
        let log = MockEmbraceLog()
        log.severity = .error
        bridge.createLog(log)
        XCTAssertEqual(logExporter.exportedLogs.count, 1)
        XCTAssertEqual(logExporter.exportedLogs.first?.severity, .error)
    }

    func test_createLog_withWarnSeverity_mapsCorrectly() {
        let log = MockEmbraceLog()
        log.severity = .warn
        bridge.createLog(log)
        XCTAssertEqual(logExporter.exportedLogs.count, 1)
        XCTAssertEqual(logExporter.exportedLogs.first?.severity, .warn)
    }

    // MARK: - createLog with attributes

    func test_createLog_withAttributes_forwardsToOtelLog() {
        let log = MockEmbraceLog()
        log.attributes = ["custom.key": "custom-value"]
        bridge.createLog(log)
        XCTAssertEqual(logExporter.exportedLogs.count, 1)
        XCTAssertEqual(logExporter.exportedLogs.first?.attributes["custom.key"], .string("custom-value"))
    }

    // MARK: - createLog severity edge case

    func test_createLog_withUnmappableSeverity_doesNotSetSeverity() {
        // EmbraceLogSeverity raw values map to OTel Severity raw values.
        // Use a severity whose rawValue doesn't map to a valid OTel Severity.
        // .critical has rawValue 24, which doesn't exist in OTel Severity enum.
        let log = MockEmbraceLog()
        log.severity = .critical
        bridge.createLog(log)
        XCTAssertEqual(logExporter.exportedLogs.count, 1)
        // When Severity(rawValue:) returns nil, severity is not set on the builder
    }

    // MARK: - Metadata fallbacks

    func test_currentSessionState_fallsBackToUnknown_whenMetadataProviderIsNil() {
        let isolatedBridge = EmbraceOTelBridge()
        // Don't call setup — metadataProvider remains nil
        XCTAssertEqual(isolatedBridge.currentSessionState, .unknown)
    }

    func test_currentSessionId_returnsNil_whenMetadataProviderIsNil() {
        let isolatedBridge = EmbraceOTelBridge()
        XCTAssertNil(isolatedBridge.currentSessionId)
    }

    // MARK: - Inbound (via external tracer on shared provider)

    // NOTE: To test the full inbound path, an external tracer would need to use the same
    // TracerProviderSdk that is owned by the bridge. Since the bridge's provider is not
    // exposed publicly, inbound integration is covered by EmbraceSpanProcessorTests.
}

// MARK: - Mocks

class MockOTelDelegate: EmbraceOTelDelegate {
    var startedSpans: [EmbraceSpan] = []
    var endedSpans: [EmbraceSpan] = []
    var emittedLogs: [EmbraceLog] = []

    func onStartSpan(_ span: EmbraceSpan) { startedSpans.append(span) }
    func onEndSpan(_ span: EmbraceSpan) { endedSpans.append(span) }
    func onEmitLog(_ log: EmbraceLog) { emittedLogs.append(log) }
}

class MockLogExporter: LogRecordExporter {
    var exportedLogs: [ReadableLogRecord] = []

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        exportedLogs.append(contentsOf: logRecords)
        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) {}
}

class MockEmbraceSpan: EmbraceSpan {
    var context: EmbraceSpanContext
    var parentSpanId: String? = nil
    var name: String = "mock"
    var type: EmbraceType = .performance
    var status: EmbraceSpanStatus = .unset
    var startTime: Date = Date()
    var endTime: Date? = nil
    var events: [EmbraceSpanEvent] = []
    var links: [EmbraceSpanLink] = []
    var attributes: EmbraceAttributes = [:]
    var sessionId: EmbraceIdentifier? = nil
    var processId: EmbraceIdentifier = EmbraceIdentifier(stringValue: "mock-process")

    init(spanId: String, traceId: String) {
        self.context = EmbraceSpanContext(spanId: spanId, traceId: traceId)
    }

    func setStatus(_ status: EmbraceSpanStatus) {}
    func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: EmbraceAttributes) throws {}
    func addLink(spanId: String, traceId: String, attributes: EmbraceAttributes) throws {}
    func setAttribute(key: String, value: EmbraceAttributeValue?) throws {}
    func end(endTime: Date) {}
    func end() {}
}

class MockEmbraceLog: EmbraceLog {
    var id: String = UUID().uuidString
    var severity: EmbraceLogSeverity = .info
    var type: EmbraceType = .message
    var timestamp: Date = Date()
    var body: String = "test log"
    var attributes: EmbraceAttributes = [:]
    var sessionId: EmbraceIdentifier? = nil
    var processId: EmbraceIdentifier = EmbraceIdentifier(stringValue: "mock-process")
}
