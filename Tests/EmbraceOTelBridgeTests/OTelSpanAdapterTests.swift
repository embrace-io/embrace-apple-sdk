//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceOTelBridge

final class OTelSpanAdapterTests: XCTestCase {

    var tracerProvider: TracerProviderSdk!
    var tracer: Tracer!
    var mockMetadataProvider: MockMetadataProvider!

    override func setUp() {
        super.setUp()
        tracerProvider = TracerProviderSdk(spanProcessors: [])
        tracer = tracerProvider.get(instrumentationName: "test", instrumentationVersion: nil)
        mockMetadataProvider = MockMetadataProvider()
    }

    func test_context_mapsSpanAndTraceId() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.context.spanId, span.context.spanId.hexString)
        XCTAssertEqual(adapter.context.traceId, span.context.traceId.hexString)
        span.end()
    }

    func test_parentSpanId_isNilWhenNoParent() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertNil(adapter.parentSpanId)
        span.end()
    }

    func test_parentSpanId_isSetWhenParentExists() {
        let parent = tracer.spanBuilder(spanName: "parent").startSpan()
        let child = tracer.spanBuilder(spanName: "child")
            .setParent(parent)
            .startSpan()
        guard let readable = child as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.parentSpanId, parent.context.spanId.hexString)
        child.end()
        parent.end()
    }

    func test_name_mapsCorrectly() {
        let span = tracer.spanBuilder(spanName: "my-span").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.name, "my-span")
        span.end()
    }

    func test_type_defaultsToPerformanceWhenNotSet() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.type, .performance)
        span.end()
    }

    func test_status_mapsUnsetCorrectly() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.status, .unset)
        span.end()
    }

    func test_status_mapsOkCorrectly() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.status = .ok
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.status, .ok)
    }

    func test_status_mapsErrorCorrectly() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.status = .error(description: "something went wrong")
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.status, .error)
    }

    func test_endTime_isNilForInProgressSpan() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertNil(adapter.endTime)
        span.end()
    }

    func test_endTime_isSetAfterSpanEnds() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertNotNil(adapter.endTime)
    }

    func test_attributes_areMapped() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.setAttribute(key: "foo", value: AttributeValue.string("bar"))
        span.setAttribute(key: "count", value: AttributeValue.int(42))
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["foo"] as? String, "bar")
        XCTAssertEqual(adapter.attributes["count"] as? Int, 42)
    }

    func test_sessionId_comesFromMetadataProvider() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.sessionId, mockMetadataProvider.currentSessionId)
        span.end()
    }

    func test_processId_comesFromMetadataProvider() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.processId, mockMetadataProvider.currentProcessId)
        span.end()
    }

    func test_mutationMethods_areNoOps() throws {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        // None of these should throw or change state
        adapter.setStatus(.ok)
        adapter.addEvent(name: "event", type: nil, timestamp: Date(), attributes: [:])
        adapter.addLink(spanId: "abc", traceId: "def", attributes: [:])
        try adapter.setAttribute(key: "k", value: "v")
        adapter.end()
        // Status remains unset since mutation is a no-op
        XCTAssertEqual(adapter.status, .unset)
        span.end()
    }

    // MARK: - type when emb.type attribute is set

    func test_type_mapsFromEmbraceTypeAttribute() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.setAttribute(key: SpanSemantics.keyEmbraceType, value: .string(EmbraceType.system.rawValue))
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.type, .system)
    }

    // MARK: - Events mapping

    func test_events_areMappedCorrectly() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        let eventTime = Date()
        span.addEvent(name: "my-event", attributes: ["evt.key": .string("evt-value")], timestamp: eventTime)
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.events.count, 1)
        XCTAssertEqual(adapter.events.first?.name, "my-event")
        XCTAssertEqual(adapter.events.first?.attributes["evt.key"] as? String, "evt-value")
    }

    // MARK: - Links mapping

    func test_links_areMappedCorrectly() {
        let linkedTraceId = TraceId(fromHexString: "abcdef1234567890abcdef1234567890")
        let linkedSpanId = SpanId(fromHexString: "abcdef1234567890")
        let linkedContext = SpanContext.create(
            traceId: linkedTraceId,
            spanId: linkedSpanId,
            traceFlags: .init(fromByte: 1),
            traceState: .init()
        )
        let span = tracer.spanBuilder(spanName: "test")
            .addLink(spanContext: linkedContext, attributes: ["link.key": .string("link-value")])
            .startSpan()
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.links.count, 1)
        XCTAssertEqual(adapter.links.first?.context.spanId, "abcdef1234567890")
        XCTAssertEqual(adapter.links.first?.context.traceId, "abcdef1234567890abcdef1234567890")
        XCTAssertEqual(adapter.links.first?.attributes["link.key"] as? String, "link-value")
    }

    // MARK: - startTime mapping

    func test_startTime_mapsCorrectly() {
        let startTime = Date(timeIntervalSince1970: 1000)
        let span = tracer.spanBuilder(spanName: "test")
            .setStartTime(time: startTime)
            .startSpan()
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.startTime.timeIntervalSince1970, 1000, accuracy: 0.001)
    }

    // MARK: - processId fallback when metadataProvider is nil

    func test_processId_fallsBackToProcessIdentifierCurrent_whenProviderIsNil() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: nil)
        XCTAssertEqual(adapter.processId, ProcessIdentifier.current)
        span.end()
    }

    // MARK: - sessionId when metadataProvider is nil

    func test_sessionId_isNil_whenMetadataProviderIsNil() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: nil)
        XCTAssertNil(adapter.sessionId)
        span.end()
    }

    // MARK: - Double attribute mapping

    func test_attributes_mapDoubleCorrectly() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.setAttribute(key: "temperature", value: AttributeValue.double(36.6))
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["temperature"] as? Double, 36.6)
    }

    // MARK: - Bool attribute mapping

    func test_attributes_mapBoolCorrectly() {
        let span = tracer.spanBuilder(spanName: "test").startSpan()
        span.setAttribute(key: "enabled", value: AttributeValue.bool(true))
        span.end()
        guard let readable = span as? ReadableSpan else {
            XCTFail("Span does not conform to ReadableSpan")
            return
        }
        let adapter = OTelSpanAdapter(span: readable, metadataProvider: mockMetadataProvider)
        XCTAssertEqual(adapter.attributes["enabled"] as? Bool, true)
    }
}
