//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

class EmbraceSpanLinkTests: XCTestCase {

    func test_init_context() {
        // given a context and attributes
        let context = EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        // when creating a span link with them
        let link = EmbraceSpanLink(context: context, attributes: ["key": "value"])

        // then the link is created correctly
        XCTAssertEqual(link.context.spanId, context.spanId)
        XCTAssertEqual(link.context.traceId, context.traceId)
        XCTAssertEqual(link.attributes.count, 1)
        XCTAssertEqual(link.attributes["key"] as! String, "value")
    }

    func test_init() {
        // given a spanId, traceId and attributes
        let spanId = TestConstants.spanId
        let traceId = TestConstants.traceId

        // when creating a span link with them
        let link = EmbraceSpanLink(spanId: spanId, traceId: traceId, attributes: ["key": "value"])

        // then the link is created correctly
        XCTAssertEqual(link.context.spanId, spanId)
        XCTAssertEqual(link.context.traceId, traceId)
        XCTAssertEqual(link.attributes.count, 1)
        XCTAssertEqual(link.attributes["key"] as! String, "value")
    }
}
