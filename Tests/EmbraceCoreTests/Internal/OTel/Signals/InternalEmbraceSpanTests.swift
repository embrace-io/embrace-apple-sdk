//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class InternalEmbraceSpanTests: XCTestCase {

    var handler: MockEmbraceSpanHandler!

    override func setUpWithError() throws {
        handler = MockEmbraceSpanHandler()
    }

    override func tearDownWithError() throws {
        handler = nil
    }

    var testSpan: DefaultEmbraceSpan {
        let context = EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId)
        let startTime = Date(timeIntervalSince1970: 1)
        let endTime = Date(timeIntervalSince1970: 2)
        let event = EmbraceSpanEvent(name: "event")
        let link = EmbraceSpanLink(spanId: "spanId", traceId: "traceId")

        return InternalEmbraceSpan(
            context: context,
            parentSpanId: "test",
            name: "name",
            type: .performance,
            status: .error,
            startTime: startTime,
            endTime: endTime,
            events: [event],
            links: [link],
            attributes: ["myKey": "myValue"],
            internalAttributeCount: 1,
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId,
            autoTerminationCode: .failure,
            handler: handler
        )
    }

    func test_addEvent_success() throws {
        // given a span
        let span = testSpan

        // when adding a new event
        try span.addEvent(
            name: "newEvent",
            type: .performance,
            timestamp: Date(timeIntervalSince1970: 5),
            attributes: ["key": "value"]
        )

        // then the event is added correctly
        // the internal counter increases
        // and the handler is notified
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.events[1].name, "newEvent")
        XCTAssertEqual(span.events[1].type, .performance)
        XCTAssertEqual(span.events[1].timestamp, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(span.events[1].attributes.count, 2)
        XCTAssertEqual(span.events[1].attributes["emb.type"] as! String, "perf")
        XCTAssertEqual(span.events[1].attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalEventCount, 1)
        XCTAssertEqual(handler.createEventCallCount, 0)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 1)
    }

    func test_setAttribute_success() throws {
        // given a span
        let span = testSpan

        // when setting a new attribute
        try span.setAttribute(key: "key", value: "value")

        // then the attribute is set
        // the internal counter increases
        // and the handler is notified
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 2)
        XCTAssertEqual(handler.validateAttributeCallCount, 0)
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 1)
    }
}
