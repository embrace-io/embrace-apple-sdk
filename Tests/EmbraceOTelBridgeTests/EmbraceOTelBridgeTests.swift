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
