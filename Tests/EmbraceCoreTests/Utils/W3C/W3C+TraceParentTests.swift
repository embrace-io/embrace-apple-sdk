//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import EmbraceSemantics
import TestSupport
import XCTest

final class W3C_TraceParentTests: XCTestCase {

    func test_w3c_traceparent_returnsCorrectValue() {
        let unsampled = W3C.traceparent(traceId: "exampletraceid", spanId: "examplespanid", sampled: false)
        let sampled = W3C.traceparent(traceId: "exampletraceid", spanId: "examplespanid", sampled: true)

        XCTAssertEqual(unsampled, "00-exampletraceid-examplespanid-00")
        XCTAssertEqual(sampled, "00-exampletraceid-examplespanid-01")
    }

    func test_w3c_traceparent_fromSpan_returnsCorrectValue() {
        let span = MockSpan(name: "example")
        let traceparent = W3C.traceparent(from: span)
        XCTAssertEqual(traceparent, "00-\(span.context.traceId)-\(span.context.spanId)-01")
    }

    func test_w3c_traceparent_fromSpanContext_returnsCorrectValue() {
        let context = EmbraceSpanContext(spanId: "spanId", traceId: "traceId")
        XCTAssertEqual(W3C.traceparent(from: context), "00-traceId-spanId-01")
    }
}
