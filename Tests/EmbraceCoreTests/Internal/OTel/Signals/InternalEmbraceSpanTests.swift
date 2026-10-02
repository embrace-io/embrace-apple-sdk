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

    /// An open span. Spans stop accepting changes once they end, so the fixture has to be open for
    /// any test that mutates it.
    var testSpan: DefaultEmbraceSpan {
        makeTestSpan()
    }

    func makeTestSpan(endTime: Date? = nil) -> DefaultEmbraceSpan {
        let context = EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId)
        let startTime = Date(timeIntervalSince1970: 1)
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
        span.addEvent(
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
        span.setAttribute(key: "key", value: "value")

        // then the attribute is set
        // the internal counter increases
        // and the handler is notified
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 2)
        XCTAssertEqual(handler.validateAttributeCallCount, 0)
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 1)
    }

    func test_setAttributes_notifiesHandlerOnce() throws {
        // given a span
        let span = testSpan

        // when setting several attributes at once, one of them already present
        span.setAttributes(["key": "value", "otherKey": "otherValue", "myKey": "newValue"])

        // then they are all set
        // the internal counter only counts the new ones
        // and the handler is notified once, without per-attribute notifications
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(span.attributes["otherKey"] as! String, "otherValue")
        XCTAssertEqual(span.attributes["myKey"] as! String, "newValue")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 3)
        XCTAssertEqual(handler.validateAttributeCallCount, 0)
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 1)
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 0)
    }

    func test_setAttributes_afterEnd_isIgnored() throws {
        // given an ended span
        let span = makeTestSpan(endTime: Date(timeIntervalSince1970: 2))

        // when setting several attributes at once
        span.setAttributes(["key": "value"])

        // then nothing changes and the handler isn't notified
        XCTAssertNil(span.attributes["key"])
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 0)
    }
}
