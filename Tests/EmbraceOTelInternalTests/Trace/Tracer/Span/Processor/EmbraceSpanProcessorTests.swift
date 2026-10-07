//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

final class EmbraceSpanProcessorTests: XCTestCase {

    var processor: EmbraceSpanProcessor!

    var childProcessor: InMemorySpanProcessor!
    var exporter: InMemorySpanExporter!
    var sdkStateProvider: MockEmbraceSDKStateProvider!

    override func setUpWithError() throws {
        childProcessor = InMemorySpanProcessor()
        exporter = InMemorySpanExporter()
        sdkStateProvider = MockEmbraceSDKStateProvider()

        processor = EmbraceSpanProcessor(
            spanProcessors: [childProcessor],
            spanExporters: [exporter],
            sdkStateProvider: sdkStateProvider,
            sessionIdProvider: {
                TestConstants.sessionId.stringValue
            }
        )
    }

    func createSpanData(
        processor: SpanProcessor,
        traceId: TraceId = .random(),
        spanId: SpanId = .random(),
        name: String = "example",
        startTime: Date = Date(),
        endTime: Date? = nil,
        attributes: AttributesDictionary? = nil,
        parentContext: SpanContext? = nil
    ) -> ReadableSpan {

        let span = SpanSdk.startSpan(
            context: .create(traceId: traceId, spanId: spanId, traceFlags: .init(), traceState: .init()),
            name: name,
            instrumentationScopeInfo: .init(),
            kind: .client,
            parentContext: parentContext,
            hasRemoteParent: false,
            spanLimits: .init(),
            spanProcessor: processor,
            clock: MillisClock(),
            resource: Resource(),
            attributes: attributes ?? .init(capacity: 10),
            links: [],
            totalRecordedLinks: 0,
            startTime: startTime
        )

        if let endTime = endTime {
            span.end(time: endTime)
        }

        return span
    }

    func createAutoTerminatedSpan(processor: SpanProcessor) -> ReadableSpan {
        var dict = AttributesDictionary(capacity: 10)
        dict.attributes[SpanSemantics.keyAutoTerminationCode] = .string(SpanErrorCode.userAbandon.rawValue)

        return createSpanData(processor: processor, attributes: dict)
    }

    func test_startSpan_sdkDisabled() throws {
        sdkStateProvider.isEnabled = false

        _ = createSpanData(processor: processor)  // DEV: `startSpan` called in this method
        drainProcessorQueue()

        XCTAssertEqual(exporter.exportedSpans.count, 0)
    }

    func test_startSpan_callsChilds() throws {
        let span = createSpanData(processor: processor)  // DEV: `startSpan` called in this method

        drainProcessorQueue()
        XCTAssertNotNil(childProcessor.startedSpans[span.context.spanId])
        XCTAssertNotNil(exporter.exportedSpans[span.context.spanId])
    }

    func test_startSpan_doesNotSetSpanStatus() throws {
        let span = createSpanData(processor: processor)  // DEV: `startSpan` called in this method

        drainProcessorQueue()
        XCTAssertEqual(childProcessor.startedSpans[span.context.spanId]!.status, .unset)
        XCTAssertEqual(exporter.exportedSpans[span.context.spanId]!.status, .unset)
    }

    func test_startSpan_sanitizesName() throws {
        let name = String(repeating: ".", count: 200)
        XCTAssertEqual(name.count, 200)

        let span = createSpanData(processor: processor, name: name)  // DEV: `startSpan` called in this method

        drainProcessorQueue()
        XCTAssertEqual(childProcessor.startedSpans[span.context.spanId]!.name.count, 128)
        XCTAssertEqual(exporter.exportedSpans[span.context.spanId]!.name.count, 128)
    }

    func test_startSpan_doestNotExportEmptyName() throws {
        let span = createSpanData(processor: processor, name: "     ")  // DEV: `startSpan` called in this method

        drainProcessorQueue()
        XCTAssertNotNil(childProcessor.startedSpans[span.context.spanId])
        XCTAssertNil(exporter.exportedSpans[span.context.spanId])
    }

    func test_startSpan_addsSessionIdAttribute() throws {
        let span = createSpanData(processor: processor)  // DEV: `startSpan` called in this method

        drainProcessorQueue()
        XCTAssertEqual(childProcessor.startedSpans[span.context.spanId]!.attributes["session.id"], .string(TestConstants.sessionId.stringValue))
        XCTAssertEqual(exporter.exportedSpans[span.context.spanId]!.attributes["session.id"], .string(TestConstants.sessionId.stringValue))
    }

    func test_endingSpan_sdkDisabled() throws {
        sdkStateProvider.isEnabled = false

        let span = createSpanData(processor: processor)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        drainProcessorQueue()

        XCTAssertEqual(childProcessor.endedSpans.count, 0)
        XCTAssertEqual(exporter.exportedSpans.count, 0)
    }

    func test_endingSpan_callsChilds() throws {
        let span = createSpanData(processor: processor)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        drainProcessorQueue()
        let processedSpan = try XCTUnwrap(childProcessor.endedSpans[span.context.spanId])
        XCTAssertEqual(processedSpan.traceId, span.context.traceId)
        XCTAssertEqual(processedSpan.spanId, span.context.spanId)
        XCTAssertEqual(processedSpan.endTime, endTime)

        let exportedSpan = try XCTUnwrap(exporter.exportedSpans[span.context.spanId])
        XCTAssertEqual(exportedSpan.traceId, span.context.traceId)
        XCTAssertEqual(exportedSpan.spanId, span.context.spanId)
        XCTAssertEqual(exportedSpan.endTime, endTime)
    }

    func test_endingSpan_setStatus_ifNoErrorCode_setsOk() throws {
        let span = createSpanData(processor: processor)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        drainProcessorQueue()

        XCTAssertEqual(exporter.exportedSpans[span.context.spanId]!.status, .ok)
    }

    func test_endingSpan_setStatus_ifErrorCode_setsError() throws {
        let span = createSpanData(processor: processor)

        span.setAttribute(key: "emb.error_code", value: SpanErrorCode.unknown.rawValue)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        drainProcessorQueue()

        XCTAssertEqual(exporter.exportedSpans[span.context.spanId]!.status, .error(description: "unknown"))
    }

    func test_shutdown_callsShutdownOnChilds() throws {
        XCTAssertFalse(childProcessor.isShutdown)
        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()
        XCTAssertTrue(childProcessor.isShutdown)
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_shutdown_processesOngoingQueue() throws {
        let count = 100
        let spans = (0..<count).map { _ in createSpanData(processor: processor) }
        spans.forEach { span in processor.onStart(parentContext: nil, span: span) }

        XCTAssertFalse(childProcessor.isShutdown)
        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()

        XCTAssertEqual(childProcessor.startedSpans.count, count)
        XCTAssertTrue(childProcessor.isShutdown)

        XCTAssertEqual(exporter.exportedSpans.count, count)
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_autoTerminateSpans_clearsCache() throws {
        // given a processor with auto terminated spans
        _ = createAutoTerminatedSpan(processor: processor)
        _ = createAutoTerminatedSpan(processor: processor)
        _ = createAutoTerminatedSpan(processor: processor)

        // when the spans are auto terminated
        processor.autoTerminateSpans()

        // then the cache is cleared
        XCTAssertEqual(processor.autoTerminationSpans.count, 0)
    }

    func test_autoTerminateSpans_endsSpans() throws {
        // given a processor with auto terminated spans
        let span = createAutoTerminatedSpan(processor: processor)

        // when the spans are auto terminated
        processor.autoTerminateSpans()
        drainProcessorQueue()

        // then the spans are ended correctly
        XCTAssertEqual(processor.autoTerminationSpans.count, 0)
        try thenSpanWasAutoTerminated(span)
    }

    func test_autoTerminateSpans_endsChildSpans() throws {
        // given a processor with auto terminated spans with child spans
        let span = createAutoTerminatedSpan(processor: processor)
        let childSpan1 = createSpanData(processor: processor, parentContext: span.context)
        let childSpan2 = createSpanData(processor: processor, parentContext: childSpan1.context)

        // when the spans are auto terminated
        processor.autoTerminateSpans()
        drainProcessorQueue()

        // then the spans are ended correctly
        XCTAssertEqual(processor.autoTerminationSpans.count, 0)
        try thenSpanWasAutoTerminated(childSpan1)
        try thenSpanWasAutoTerminated(childSpan2)
    }
}

extension EmbraceSpanProcessorTests {
    /// Blocks until every block already queued on the processor queue has run.
    ///
    /// `onStart` and `onEnd` forward to the child processors and exporters asynchronously on
    /// `processorQueue`, so once it drains every span started or ended before the call has reached them.
    fileprivate func drainProcessorQueue() {
        processor.processorQueue.sync {}
    }

    fileprivate func thenSpanWasAutoTerminated(
        _ span: ReadableSpan,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let exported = try XCTUnwrap(exporter.exportedSpans[span.context.spanId], file: file, line: line)
        XCTAssertTrue(exported.hasEnded, file: file, line: line)
        XCTAssertTrue(exported.status.isError, file: file, line: line)
        XCTAssertEqual(exported.attributes[SpanSemantics.keyErrorCode], .string("user_abandon"), file: file, line: line)
    }
}
