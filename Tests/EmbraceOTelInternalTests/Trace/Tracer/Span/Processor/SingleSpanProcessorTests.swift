//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceOTelInternal
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import TestSupport
import EmbraceSemantics

final class SingleSpanProcessorTests: XCTestCase {

    var exporter: InMemorySpanExporter!

    override func setUpWithError() throws {
        exporter = InMemorySpanExporter()
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

        let span = RecordEventsReadableSpan.startSpan(
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

    func test_startSpan_callsExporter() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)

        let expectation = expectation(description: "didExport onStart")
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor) // DEV: `startSpan` called in this method

        wait(for: [expectation])
        XCTAssertNotNil(exporter.exportedSpans[span.context.spanId])
    }

    func test_startSpan_doesNotSetSpanStatus() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)

        let expectation = expectation(description: "didExport onStart")
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor) // DEV: `startSpan` called in this method

        wait(for: [expectation])
        let exportedSpan = try XCTUnwrap(exporter.exportedSpans[span.context.spanId])
        XCTAssertEqual(exportedSpan.status, .unset)
    }

    func test_endingSpan_callsExporter() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)
        let expectation = expectation(description: "didExport onEnd")
        expectation.expectedFulfillmentCount = 2        // DEV: need 2 to handle start and end
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        wait(for: [expectation])
        let exportedSpan = try XCTUnwrap(exporter.exportedSpans[span.context.spanId])
        XCTAssertEqual(exportedSpan.traceId, span.context.traceId)
        XCTAssertEqual(exportedSpan.spanId, span.context.spanId)
        XCTAssertEqual(exportedSpan.endTime, endTime)
    }

    func test_endingSpan_setStatus_ifNoErrorCode_setsOk() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)
        let expectation = expectation(description: "didExport onEnd")
        expectation.expectedFulfillmentCount = 2        // DEV: need 2 to handle start and end
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        wait(for: [expectation])
        let exportedSpan = try XCTUnwrap(exporter.exportedSpans[span.context.spanId])
        XCTAssertEqual(exportedSpan.traceId, span.context.traceId)
        XCTAssertEqual(exportedSpan.spanId, span.context.spanId)
        XCTAssertEqual(exportedSpan.endTime, endTime)
        XCTAssertEqual(exportedSpan.status, .ok)
    }

    func test_endingSpan_setStatus_ifErrorCode_setsError() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)
        let expectation = expectation(description: "didExport onEnd")
        expectation.expectedFulfillmentCount = 2        // DEV: need 2 to handle start and end
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor)

        span.setAttribute(key: "emb.error_code", value: SpanErrorCode.unknown.rawValue)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        wait(for: [expectation])
        let exportedSpan = try XCTUnwrap(exporter.exportedSpans[span.context.spanId])
        XCTAssertEqual(exportedSpan.traceId, span.context.traceId)
        XCTAssertEqual(exportedSpan.spanId, span.context.spanId)
        XCTAssertEqual(exportedSpan.endTime, endTime)
        XCTAssertEqual(exportedSpan.status, .error(description: "unknown"))
    }

    func test_shutdown_callsShutdownOnExporter() throws {
        var processor = SingleSpanProcessor(spanExporter: exporter)

        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_shutdown_processesOngoingQueue() throws {
        var processor = SingleSpanProcessor(spanExporter: exporter)

        let count = 100
        let spans = (0..<count).map { _ in createSpanData(processor: processor) }
        spans.forEach { span in processor.onStart(parentContext: nil, span: span) }

        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()

        XCTAssertEqual(exporter.exportedSpans.count, count)
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_autoTerminateSpans_clearsCache() throws {
        // given a processor with auto terminated spans
        let processor = SingleSpanProcessor(spanExporter: exporter)

        _ = createAutoTerminatedSpan(processor: processor)
        _ = createAutoTerminatedSpan(processor: processor)
        _ = createAutoTerminatedSpan(processor: processor)

        // when the spans are auto terminated
        processor.autoTerminateSpans()

        // then the cache is cleared
        wait {
            return processor.autoTerminationSpans.count == 0
        }
    }

    func test_autoTerminateSpans_endsSpans() throws {
        // given a processor with auto terminated spans
        let processor = SingleSpanProcessor(spanExporter: exporter)

        let span = createAutoTerminatedSpan(processor: processor)

        // when the spans are auto terminated
        processor.autoTerminateSpans()

        // then the spans are ended correctly
        wait {
            guard processor.autoTerminationSpans.count == 0 else {
                return false
            }

            let exportedSpan = try XCTUnwrap(self.exporter.exportedSpans[span.context.spanId])
            return exportedSpan.hasEnded &&
                   exportedSpan.status.isError &&
                   exportedSpan.attributes[SpanSemantics.keyErrorCode] == .string("user_abandon")
        }
    }

    func test_autoTerminateSpans_endsChildSpans() throws {
        // given a processor with auto terminated spans with child spans
        let processor = SingleSpanProcessor(spanExporter: exporter)

        let span = createAutoTerminatedSpan(processor: processor)
        let childSpan1 = createSpanData(processor: processor, parentContext: span.context)
        let childSpan2 = createSpanData(processor: processor, parentContext: childSpan1.context)

        // when the spans are auto terminated
        processor.autoTerminateSpans()

        // then the spans are ended correctly
        wait {
            guard processor.autoTerminationSpans.count == 0 else {
                return false
            }

            let span1 = try XCTUnwrap(self.exporter.exportedSpans[childSpan1.context.spanId])
            let span2 = try XCTUnwrap(self.exporter.exportedSpans[childSpan2.context.spanId])

            return span1.hasEnded &&
                   span1.status.isError &&
                   span1.attributes[SpanSemantics.keyErrorCode] == .string("user_abandon") &&
                   span2.hasEnded &&
                   span2.status.isError &&
                   span2.attributes[SpanSemantics.keyErrorCode] == .string("user_abandon")
        }
    }
}
