//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceOTelBridge

final class EmbraceSpanProcessorTests: XCTestCase {

    var tracerProvider: TracerProviderSdk!
    var embraceProcessor: EmbraceSpanProcessor!
    var mockDelegate: MockSpanProcessorDelegate!
    var tracer: Tracer!

    override func setUp() {
        super.setUp()
        mockDelegate = MockSpanProcessorDelegate()
        embraceProcessor = EmbraceSpanProcessor(delegate: mockDelegate)
        tracerProvider = TracerProviderSdk(spanProcessors: [embraceProcessor])
        tracer = tracerProvider.get(instrumentationName: "test", instrumentationVersion: nil)
    }

    func test_onStart_forwardsExternalSpanToDelegate() {
        let span = tracer.spanBuilder(spanName: "external").startSpan()
        XCTAssertEqual(mockDelegate.startedSpans.count, 1)
        XCTAssertEqual(mockDelegate.startedSpans.first?.name, "external")
        span.end()
    }

    func test_onEnd_forwardsExternalSpanToDelegate() {
        let span = tracer.spanBuilder(spanName: "external").startSpan()
        span.end()
        XCTAssertEqual(mockDelegate.endedSpans.count, 1)
        XCTAssertEqual(mockDelegate.endedSpans.first?.name, "external")
    }

    func test_onStart_skipsInternalSpans() {
        mockDelegate.internalSpanNames = ["internal-span"]
        let span = tracer.spanBuilder(spanName: "internal-span").startSpan()
        XCTAssertEqual(mockDelegate.startedSpans.count, 0)
        span.end()
    }

    func test_onEnd_skipsInternalSpans() {
        mockDelegate.internalSpanNames = ["internal-span"]
        let span = tracer.spanBuilder(spanName: "internal-span").startSpan()
        span.end()
        XCTAssertEqual(mockDelegate.endedSpans.count, 0)
    }

    func test_noDelegate_doesNotCrash() {
        let processor = EmbraceSpanProcessor(delegate: nil)
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)
        let span = t.spanBuilder(spanName: "test").startSpan()
        span.end()
        // No crash — test passes
    }
}

// MARK: - Mock

class MockSpanProcessorDelegate: EmbraceSpanProcessorDelegate {
    var internalSpanNames: Set<String> = []
    var startedSpans: [ReadableSpan] = []
    var endedSpans: [ReadableSpan] = []

    func isInternalSpan(_ span: ReadableSpan) -> Bool {
        return internalSpanNames.contains(span.name)
    }

    func onExternalSpanStarted(_ span: ReadableSpan) {
        startedSpans.append(span)
    }

    func onExternalSpanEnded(_ span: ReadableSpan) {
        endedSpans.append(span)
    }
}
