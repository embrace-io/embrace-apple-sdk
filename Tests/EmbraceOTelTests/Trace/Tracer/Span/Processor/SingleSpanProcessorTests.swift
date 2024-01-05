//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceOTel
import OpenTelemetryApi

final class SingleSpanProcessorTests: XCTestCase {

    let exporter = InMemorySpanExporter()

    func createSpanData(
        processor: EmbraceSpanProcessor,
        traceId: TraceId = .random(),
        spanId: SpanId = .random(),
        name: String = "example",
        startTime: Date = Date(),
        endTime: Date? = nil
    ) -> RecordingSpan {

        return RecordingSpan(
            startTime: startTime,
            context: SpanContext.create(
                traceId: traceId,
                spanId: spanId,
                traceFlags: .init(),
                traceState: .init()),
            name: name,
            processor: processor)
    }

    func test_onStart_callsExporter() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)
        let expectation = expectation(description: "didExport onStart")
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor)
        processor.onStart(span: span)

        wait(for: [expectation])
        XCTAssertEqual(exporter.exportedSpans[span.context.spanId], span.spanData)
    }

    func test_onEnd_callsExporter() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)
        let expectation = expectation(description: "didExport onEnd")
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor, endTime: Date().addingTimeInterval(10))
        processor.onEnd(span: span)

        wait(for: [expectation])
        XCTAssertEqual(exporter.exportedSpans[span.context.spanId], span.spanData)
    }

    func test_endingSpan_callsExporter() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)
        let expectation = expectation(description: "didExport onEnd")
        exporter.onExportComplete {
            expectation.fulfill()
        }

        let span = createSpanData(processor: processor)
        let endTime = Date().addingTimeInterval(2)
        span.end(time: endTime)

        wait(for: [expectation])
        let exportedSpan = exporter.exportedSpans[span.context.spanId]
        XCTAssertEqual(exportedSpan, span.spanData)
        XCTAssertEqual(exportedSpan?.endTime, endTime)
    }

    func test_shutdown_callsShutdownOnExporter() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)

        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_shutdown_processesOngoingQueue() throws {
        let processor = SingleSpanProcessor(spanExporter: exporter)

        let count = 100
        let spans = (0..<count).map { _ in createSpanData(processor: processor) }
        spans.forEach { span in processor.onStart(span: span) }

        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()

        XCTAssertEqual(exporter.exportedSpans.count, count)
        XCTAssertTrue(exporter.isShutdown)
    }

}
