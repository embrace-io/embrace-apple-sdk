//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceOTel
@testable import OpenTelemetrySdk
import TestSupport

final class SingleSpanProcessorTests: XCTestCase {

    let exporter = InMemorySpanExporter()

    func createSpanData(
        processor: EmbraceSpanProcessor,
        traceId: TraceId = .random(),
        spanId: SpanId = .random(),
        name: String = "example",
        startTime: Date = Date(),
        endTime: Date? = nil
    ) -> ReadableSpan {

        let span = RecordEventsReadableSpan.startSpan(
            context: .create(traceId: traceId, spanId: spanId, traceFlags: .init(), traceState: .init()),
            name: name,
            instrumentationScopeInfo: .init(),
            kind: .client,
            parentContext: nil,
            hasRemoteParent: false,
            spanLimits: .init(),
            spanProcessor: processor,
            clock: MillisClock(),
            resource: Resource(),
            attributes: .init(capacity: 10),
            links: [],
            totalRecordedLinks: 0,
            startTime: startTime
        )

        if let endTime = endTime {
            span.end(time: endTime)
        }

        return span
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
        let exportedSpan = exporter.exportedSpans[span.context.spanId]
        XCTAssertEqual(exportedSpan, span.toSpanData())
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
        spans.forEach { span in processor.onStart(parentContext: nil, span: span) }

        XCTAssertFalse(exporter.isShutdown)
        processor.shutdown()

        XCTAssertEqual(exporter.exportedSpans.count, count)
        XCTAssertTrue(exporter.isShutdown)
    }

}
