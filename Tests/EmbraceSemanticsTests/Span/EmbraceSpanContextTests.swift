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
}
