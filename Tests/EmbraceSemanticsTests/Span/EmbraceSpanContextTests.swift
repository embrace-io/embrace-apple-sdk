//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

class EmbraceSpanContextTests: XCTestCase {

    func test_init() {
        // given a spanId and traceId
        let spanId = TestConstants.spanId
        let traceId = TestConstants.traceId

        // when creating a span context with them
        let context = EmbraceSpanContext(spanId: spanId, traceId: traceId)

        // then the context is created correctly
        XCTAssertEqual(context.spanId, spanId)
        XCTAssertEqual(context.traceId, traceId)
    }

    // MARK: Validation

    func test_isValidTraceId_acceptsWellFormedIdentifiers() {
        XCTAssertTrue(EmbraceSpanContext.isValidTraceId(TestConstants.traceId))
        XCTAssertTrue(EmbraceSpanContext.isValidTraceId("abcdef1234567890abcdef1234567890"))

        // accepted so it can be normalized, rather than rejected outright
        XCTAssertTrue(EmbraceSpanContext.isValidTraceId("ABCDEF1234567890ABCDEF1234567890"))
    }

    func test_isValidTraceId_rejectsMalformedIdentifiers() {
        XCTAssertFalse(EmbraceSpanContext.isValidTraceId(""))

        // all zeros
        XCTAssertFalse(EmbraceSpanContext.isValidTraceId("00000000000000000000000000000000"))

        // too short
        XCTAssertFalse(EmbraceSpanContext.isValidTraceId("abcdef1234567890"))

        // too long
        XCTAssertFalse(EmbraceSpanContext.isValidTraceId("abcdef1234567890abcdef1234567890ab"))

        // not hexadecimal
        XCTAssertFalse(EmbraceSpanContext.isValidTraceId("zzzzzz1234567890abcdef1234567890"))

        // fullwidth digits are hex digits to `Character.isHexDigit`, but not usable identifiers
        XCTAssertFalse(EmbraceSpanContext.isValidTraceId("１bcdef1234567890abcdef1234567890"))
    }

    func test_isValidSpanId_acceptsWellFormedIdentifiers() {
        XCTAssertTrue(EmbraceSpanContext.isValidSpanId(TestConstants.spanId))
        XCTAssertTrue(EmbraceSpanContext.isValidSpanId("abcdef1234567890"))
        XCTAssertTrue(EmbraceSpanContext.isValidSpanId("ABCDEF1234567890"))
    }

    func test_isValidSpanId_rejectsMalformedIdentifiers() {
        XCTAssertFalse(EmbraceSpanContext.isValidSpanId(""))
        XCTAssertFalse(EmbraceSpanContext.isValidSpanId("0000000000000000"))
        XCTAssertFalse(EmbraceSpanContext.isValidSpanId("abcdef123456789"))
        XCTAssertFalse(EmbraceSpanContext.isValidSpanId("abcdef1234567890ab"))
        XCTAssertFalse(EmbraceSpanContext.isValidSpanId("zzzzzz1234567890"))
    }

    func test_isValid_requiresBothIdentifiers() {
        XCTAssertTrue(
            EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId).isValid
        )
        XCTAssertFalse(
            EmbraceSpanContext(spanId: "invalid", traceId: TestConstants.traceId).isValid
        )
        XCTAssertFalse(
            EmbraceSpanContext(spanId: TestConstants.spanId, traceId: "invalid").isValid
        )
    }

    func test_normalize_lowercasesIdentifiers() {
        XCTAssertEqual(
            EmbraceSpanContext.normalize("ABCDEF1234567890ABCDEF1234567890"),
            "abcdef1234567890abcdef1234567890"
        )
    }
}
