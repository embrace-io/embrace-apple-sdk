//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultOTelSignalBridgeTests: XCTestCase {

    func test_startSpan() throws {
        // given a bridge
        let bridge = DefaultOTelSignalBridge()

        // when starting a span
        let context = bridge.startSpan(
            name: "test",
            parentSpan: nil,
            status: .ok,
            startTime: Date(),
            endTime: Date(),
            events: [],
            links: [],
            attributes: [:]
        )

        // then the context for the span is created correctly
        XCTAssertNotNil(context)
        XCTAssertEqual(context.spanId.count, 16)
        XCTAssertEqual(context.traceId.count, 32)
    }

    func test_startSpan_withParent() throws {
        // given a bridge
        let bridge = DefaultOTelSignalBridge()

        // when starting a span with a parent
        let parent = DefaultEmbraceSpan(
            context: EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId),
            parentSpanId: nil,
            name: "parent"
        )

        let context = bridge.startSpan(
            name: "test",
            parentSpan: parent,
            status: .ok,
            startTime: Date(),
            endTime: Date(),
            events: [],
            links: [],
            attributes: [:]
        )

        // then the context for the span is created correctly
        XCTAssertNotNil(context)
        XCTAssertEqual(context.spanId.count, 16)
        XCTAssertEqual(context.traceId, parent.context.traceId)
    }
}
