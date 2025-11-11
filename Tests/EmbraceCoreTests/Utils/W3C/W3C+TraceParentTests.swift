//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import EmbraceOTelInternal
import OpenTelemetryApi
@preconcurrency import OpenTelemetrySdk
import XCTest

final class W3C_TraceParentTests: XCTestCase {

    override func setUp() async throws {
        // Setup with alwaysOff sampler to ensure unsampled spans for testing
        // Register the tracer provider directly without calling EmbraceOTel.setup()
        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderSdk(
                sampler: Samplers.alwaysOff,
                spanProcessors: []
            )
        )
    }

    func test_w3c_traceparent_returnsCorrectValue() {
        let unsampled = W3C.traceparent(traceId: "exampletraceid", spanId: "examplespanid", sampled: false)
        let sampled = W3C.traceparent(traceId: "exampletraceid", spanId: "examplespanid", sampled: true)

        XCTAssertEqual(unsampled, "00-exampletraceid-examplespanid-00")
        XCTAssertEqual(sampled, "00-exampletraceid-examplespanid-01")
    }

    func test_w3c_traceparent_fromSpan_returnsCorrectValue() {
        let span = EmbraceOTel()
            .buildSpan(name: "example", type: .performance)
            .startSpan()

        let traceparent = W3C.traceparent(from: span)
        // Verify that the traceparent matches the span's actual sampled state
        let expectedSampledFlag = span.context.traceFlags.sampled ? "01" : "00"
        XCTAssertEqual(
            traceparent,
            "00-\(span.context.traceId.hexString)-\(span.context.spanId.hexString)-\(expectedSampledFlag)"
        )
    }

    func test_w3c_traceparent_fromSpanContext_returnsCorrectValue() {
        let unsampled = SpanContext.create(
            traceId: .random(),
            spanId: .random(),
            traceFlags: .init(),
            traceState: .init()
        )

        XCTAssertEqual(
            W3C.traceparent(from: unsampled),
            "00-\(unsampled.traceId.hexString)-\(unsampled.spanId.hexString)-00"
        )

        let sampled = SpanContext.create(
            traceId: .random(),
            spanId: .random(),
            traceFlags: .init(fromByte: 0x1),
            traceState: .init()
        )

        XCTAssertEqual(
            W3C.traceparent(from: sampled),
            "00-\(sampled.traceId.hexString)-\(sampled.spanId.hexString)-01"
        )
    }

}
