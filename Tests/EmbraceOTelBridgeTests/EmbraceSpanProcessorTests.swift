//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceOTelBridge
@testable import EmbraceSemantics

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

    // MARK: - Attribute injection on external spans

    func test_onStart_injectsEmbraceTypeOnExternalSpan() {
        mockDelegate.currentSessionState = .foreground
        mockDelegate.currentSessionId = EmbraceIdentifier(stringValue: "part-123")
        mockDelegate.currentUserSessionId = EmbraceIdentifier(stringValue: "user-123")
        let span = tracer.spanBuilder(spanName: "external").startSpan()

        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let data = readable.toSpanData()
        XCTAssertEqual(data.attributes[SpanSemantics.keyEmbraceType], .string(EmbraceType.performance.rawValue))
        XCTAssertEqual(data.attributes[SpanSemantics.Session.keyState], .string("foreground"))
        // session.id carries the user-session id; the part id lives under emb.session_part_id.
        XCTAssertEqual(data.attributes[SpanSemantics.keySessionId], .string("user-123"))
        XCTAssertEqual(data.attributes[SpanSemantics.Session.keyUserSessionId], .string("user-123"))
        XCTAssertEqual(data.attributes[SpanSemantics.Session.keyPartId], .string("part-123"))
        span.end()
    }

    func test_onStart_stampsEmptyStringsWhenIdentifiersAreNil() {
        mockDelegate.currentSessionId = nil
        mockDelegate.currentUserSessionId = nil
        let span = tracer.spanBuilder(spanName: "external").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let data = readable.toSpanData()
        // Spec: all three identity keys are present even as empty strings.
        XCTAssertEqual(data.attributes[SpanSemantics.keySessionId], .string(""))
        XCTAssertEqual(data.attributes[SpanSemantics.Session.keyUserSessionId], .string(""))
        XCTAssertEqual(data.attributes[SpanSemantics.Session.keyPartId], .string(""))
        span.end()
    }

    // MARK: - Child processor forwarding

    func test_onStart_forwardsToChildProcessors() {
        let childProcessor = CapturingSpanProcessor()
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)

        let span = t.spanBuilder(spanName: "test-span").startSpan()
        processor.waitForAllWork()

        XCTAssertEqual(childProcessor.startedSpanNames, ["test-span"])
        span.end()
    }

    func test_onEnd_forwardsToChildProcessors() {
        let childProcessor = CapturingSpanProcessor()
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)

        let span = t.spanBuilder(spanName: "test-span").startSpan()
        span.end()
        processor.waitForAllWork()

        XCTAssertEqual(childProcessor.endedSpanNames, ["test-span"])
    }

    // MARK: - Child exporter forwarding on onEnd

    func test_onEnd_forwardsSpanDataToChildExporters() {
        let childExporter = CapturingSpanExporter()
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childExporters: [childExporter])
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)

        let span = t.spanBuilder(spanName: "exported-span").startSpan()
        span.end()
        processor.waitForAllWork()

        XCTAssertEqual(childExporter.exportedSpans.map(\.name), ["exported-span"])
    }

    // MARK: - forceFlush propagation

    func test_forceFlush_propagatesToChildProcessorsAndExporters() {
        let childProcessor = CapturingSpanProcessor()
        let childExporter = CapturingSpanExporter()
        let processor = EmbraceSpanProcessor(
            delegate: mockDelegate,
            childProcessors: [childProcessor],
            childExporters: [childExporter]
        )

        processor.forceFlush(timeout: 5.0)

        XCTAssertTrue(childProcessor.didForceFlush)
        XCTAssertTrue(childExporter.didFlush)
    }

    // MARK: - shutdown propagation

    func test_shutdown_propagatesToChildProcessorsAndExporters() {
        let childProcessor = CapturingSpanProcessor()
        let childExporter = CapturingSpanExporter()
        let processor = EmbraceSpanProcessor(
            delegate: mockDelegate,
            childProcessors: [childProcessor],
            childExporters: [childExporter]
        )

        processor.shutdown(explicitTimeout: 5.0)

        XCTAssertTrue(childProcessor.didShutdown)
        XCTAssertTrue(childExporter.didShutdown)
    }

    // MARK: - Async dispatch behavior

    func test_childForwarding_isAsyncWhileDelegateCallsAreSynchronous() {
        let childProcessor = CapturingSpanProcessor()
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)

        // Holding the critical resource group blocks processorQueue, so child forwarding cannot run
        // until it is released.
        let criticalResourceGroup = DispatchGroup()
        criticalResourceGroup.enter()
        processor.criticalResourceGroup = criticalResourceGroup

        let span = t.spanBuilder(spanName: "async-test").startSpan()
        span.end()

        XCTAssertEqual(mockDelegate.startedSpans.count, 1)
        XCTAssertEqual(mockDelegate.endedSpans.count, 1)
        XCTAssertTrue(childProcessor.startedSpanNames.isEmpty)
        XCTAssertTrue(childProcessor.endedSpanNames.isEmpty)

        criticalResourceGroup.leave()
        processor.waitForAllWork()

        XCTAssertEqual(childProcessor.startedSpanNames, ["async-test"])
        XCTAssertEqual(childProcessor.endedSpanNames, ["async-test"])
    }
}

// MARK: - Mocks

class MockSpanProcessorDelegate: EmbraceSpanProcessorDelegate {
    var internalSpanNames: Set<String> = []
    var startedSpans: [ReadableSpan] = []
    var endedSpans: [ReadableSpan] = []
    var currentSessionState: SessionState = .foreground
    var currentSessionId: EmbraceIdentifier? = nil
    var currentUserSessionId: EmbraceIdentifier? = nil

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

class CapturingSpanProcessor: SpanProcessor {
    var isStartRequired: Bool { true }
    var isEndRequired: Bool { true }

    // EmbraceSpanProcessor forwards to child processors on a background queue while tests read these
    // on the main thread, so guard them with a lock.
    @TestLocked var startedSpanNames: [String] = []
    @TestLocked var endedSpanNames: [String] = []
    @TestLocked var didForceFlush = false
    @TestLocked var didShutdown = false

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        startedSpanNames.append(span.name)
    }

    func onEnd(span: ReadableSpan) {
        endedSpanNames.append(span.name)
    }

    func forceFlush(timeout: TimeInterval?) {
        didForceFlush = true
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }
}

class CapturingSpanExporter: SpanExporter {
    // `export` is called on a background queue while tests read these on the main thread; guard them.
    @TestLocked var exportedSpans: [SpanData] = []
    @TestLocked var didFlush = false
    @TestLocked var didShutdown = false

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        exportedSpans.append(contentsOf: spans)
        return .success
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        didFlush = true
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        didShutdown = true
    }
}
