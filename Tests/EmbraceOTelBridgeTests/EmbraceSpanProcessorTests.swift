//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
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
        // Child forwarding is async on processorQueue
        let expectation = expectation(description: "child processor receives onStart")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if childProcessor.startedSpanNames.contains("test-span") {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: .defaultTimeout)
        span.end()
    }

    func test_onEnd_forwardsToChildProcessors() {
        let childProcessor = CapturingSpanProcessor()
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childProcessors: [childProcessor])
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)

        let span = t.spanBuilder(spanName: "test-span").startSpan()
        span.end()

        let expectation = expectation(description: "child processor receives onEnd")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if childProcessor.endedSpanNames.contains("test-span") {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: .defaultTimeout)
    }

    // MARK: - Child exporter forwarding on onEnd

    func test_onEnd_forwardsSpanDataToChildExporters() {
        let childExporter = CapturingSpanExporter()
        let processor = EmbraceSpanProcessor(delegate: mockDelegate, childExporters: [childExporter])
        let provider = TracerProviderSdk(spanProcessors: [processor])
        let t = provider.get(instrumentationName: "test", instrumentationVersion: nil)

        let span = t.spanBuilder(spanName: "exported-span").startSpan()
        span.end()

        let expectation = expectation(description: "child exporter receives span data")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if childExporter.exportedSpans.contains(where: { $0.name == "exported-span" }) {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: .defaultTimeout)
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

        let span = t.spanBuilder(spanName: "async-test").startSpan()

        // Delegate call is synchronous — should be populated immediately after startSpan()
        XCTAssertEqual(mockDelegate.startedSpans.count, 1)

        // Child processor forwarding is async — should NOT be populated yet on the calling thread
        // (though it may have been dispatched)
        // We verify it eventually arrives
        span.end()

        let expectation = expectation(description: "child processor eventually receives span")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if childProcessor.endedSpanNames.contains("async-test") {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: .defaultTimeout)
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
    private let lock = NSLock()

    private var _startedSpanNames: [String] = []
    var startedSpanNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _startedSpanNames
    }

    private var _endedSpanNames: [String] = []
    var endedSpanNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _endedSpanNames
    }

    private var _didForceFlush = false
    var didForceFlush: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didForceFlush
    }

    private var _didShutdown = false
    var didShutdown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didShutdown
    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        lock.lock()
        defer { lock.unlock() }
        _startedSpanNames.append(span.name)
    }

    func onEnd(span: ReadableSpan) {
        lock.lock()
        defer { lock.unlock() }
        _endedSpanNames.append(span.name)
    }

    func forceFlush(timeout: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        _didForceFlush = true
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        _didShutdown = true
    }
}

class CapturingSpanExporter: SpanExporter {
    // `export` is called on a background queue while tests read these on the main thread; guard them.
    private let lock = NSLock()

    private var _exportedSpans: [SpanData] = []
    var exportedSpans: [SpanData] {
        lock.lock()
        defer { lock.unlock() }
        return _exportedSpans
    }

    private var _didFlush = false
    var didFlush: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didFlush
    }

    private var _didShutdown = false
    var didShutdown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didShutdown
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        defer { lock.unlock() }
        _exportedSpans.append(contentsOf: spans)
        return .success
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        defer { lock.unlock() }
        _didFlush = true
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        _didShutdown = true
    }
}
