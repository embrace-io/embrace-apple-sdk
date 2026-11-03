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

    func test_w3c_traceparent_withFlags_writesThemVerbatim() {
        XCTAssertEqual(W3C.traceparent(traceId: "traceId", spanId: "spanId", flags: "03"), "00-traceId-spanId-03")
        XCTAssertEqual(W3C.traceparent(traceId: "traceId", spanId: "spanId", flags: "00"), "00-traceId-spanId-00")
    }

    // MARK: - Parsing

    private let traceId = "4bf92f3577b34da6a3ce929d0e0e4736"
    private let spanId = "00f067aa0ba902b7"

    func test_parseTraceparent_validVersion00_returnsFieldsVerbatim() throws {
        for flags in ["00", "01", "03", "ff"] {
            let parsed = try XCTUnwrap(W3C.parseTraceparent("00-\(traceId)-\(spanId)-\(flags)"))
            XCTAssertEqual(parsed.traceId, traceId)
            XCTAssertEqual(parsed.spanId, spanId)
            XCTAssertEqual(parsed.flags, flags)
            XCTAssertEqual(parsed.context.traceId, traceId)
            XCTAssertEqual(parsed.context.spanId, spanId)
        }
    }

    func test_parseTraceparent_laterVersionWithExtraFields_parsesFirstFourFields() throws {
        let parsed = try XCTUnwrap(W3C.parseTraceparent("01-\(traceId)-\(spanId)-01-whatever-else"))
        XCTAssertEqual(parsed.traceId, traceId)
        XCTAssertEqual(parsed.spanId, spanId)
        XCTAssertEqual(parsed.flags, "01")
    }

    func test_parseTraceparent_laterVersionWithFourFields_isValid() {
        XCTAssertNotNil(W3C.parseTraceparent("cc-\(traceId)-\(spanId)-01"))
    }

    func test_parseTraceparent_invalidValues_returnNil() {
        let invalid: [String?] = [
            nil,
            "",
            "00",
            "00-\(traceId)-\(spanId)",
            // wrong lengths
            "0-\(traceId)-\(spanId)-01",
            "00-\(traceId.dropLast())-\(spanId)-01",
            "00-\(traceId)-\(spanId)0-01",
            "00-\(traceId)-\(spanId)-1",
            // non hex
            "00-\(traceId.dropLast())g-\(spanId)-01",
            "00-\(traceId)-\(spanId.dropLast())z-01",
            "00-\(traceId)-\(spanId)-0x",
            // uppercase
            "00-\(traceId.uppercased())-\(spanId)-01",
            "00-\(traceId)-\(spanId.uppercased())-01",
            "00-\(traceId)-\(spanId)-0A",
            // fullwidth digits
            "00-\(traceId.dropLast())１-\(spanId)-01",
            // all zeros
            "00-00000000000000000000000000000000-\(spanId)-01",
            "00-\(traceId)-0000000000000000-01",
            // forbidden version
            "ff-\(traceId)-\(spanId)-01",
            // version 00 with extra fields
            "00-\(traceId)-\(spanId)-01-extra",
            // duplicate headers, as reported by URLRequest
            "00-\(traceId)-\(spanId)-01,00-\(traceId)-\(spanId)-01",
            // whitespace
            " 00-\(traceId)-\(spanId)-01",
            "00-\(traceId)-\(spanId)-01 "
        ]

        for value in invalid {
            XCTAssertNil(W3C.parseTraceparent(value), "Expected '\(value ?? "nil")' to be rejected")
        }
    }
}
