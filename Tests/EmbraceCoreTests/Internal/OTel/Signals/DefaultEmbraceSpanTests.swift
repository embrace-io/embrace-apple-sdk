//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultEmbraceSpanTests: XCTestCase {

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

        return DefaultEmbraceSpan(
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

    func test_init() {
        // when initializing a span
        let span = testSpan

        // then the values are stored correctly
        XCTAssertEqual(span.context.spanId, TestConstants.spanId)
        XCTAssertEqual(span.context.traceId, TestConstants.traceId)
        XCTAssertEqual(span.parentSpanId, "test")
        XCTAssertEqual(span.name, "name")
        XCTAssertEqual(span.type, .performance)
        XCTAssertEqual(span.status, .error)
        XCTAssertEqual(span.startTime, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(span.endTime, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(span.events[0].name, "event")
        XCTAssertEqual(span.links[0].context.spanId, "spanId")
        XCTAssertEqual(span.links[0].context.traceId, "traceId")
        XCTAssertEqual(span.attributes.count, 1)
        XCTAssertEqual(span.attributes["myKey"] as! String, "myValue")
        XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
        XCTAssertEqual(span.state.safeValue.internalLinkCount, 0)
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
        XCTAssertEqual(span.sessionId, TestConstants.sessionId)
        XCTAssertEqual(span.processId, TestConstants.processId)
        XCTAssertEqual(span.autoTerminationCode, .failure)
    }

    func test_setStatus() {
        // given a span
        let span = testSpan

        // when setting the status
        span.setStatus(.ok)

        // then the status is updated and the handler is notified
        XCTAssertEqual(span.status, .ok)
        XCTAssertEqual(handler.onSpanStatusUpdatedCallCount, 1)
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
        // the internal counter doesn't increase
        // and the handler is notified
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.events[1].name, "newEvent")
        XCTAssertEqual(span.events[1].type, .performance)
        XCTAssertEqual(span.events[1].timestamp, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(span.events[1].attributes.count, 2)
        XCTAssertEqual(span.events[1].attributes["emb.type"] as! String, "perf")
        XCTAssertEqual(span.events[1].attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
        XCTAssertEqual(handler.createEventCallCount, 1)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 1)
    }

    func test_addEvent_failure() throws {
        // given a span
        let span = testSpan

        // when adding a new event that would fail
        handler.createEventError = EmbraceOTelError.spanEventLimitReached("test")

        XCTAssertThrowsError(
            try span.addEvent(
                name: "newEvent",
                type: .performance,
                timestamp: Date(timeIntervalSince1970: 5),
                attributes: ["key": "value"]
            )
        ) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -3)
            XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
            XCTAssertEqual(handler.createEventCallCount, 1)
            XCTAssertEqual(handler.onSpanEventAddedCallCount, 0)
        }
    }

    func test_addSessionEvent_success() throws {
        // given a span
        let span = testSpan

        // when adding a new session event
        try span.addSessionEvent(
            name: "newSessionEvent",
            type: .performance,
            timestamp: Date(timeIntervalSince1970: 5),
            attributes: ["key1": "value1"],
            internalAttributes: ["key2": "value2"],
            isInternal: false
        )

        // then the event is added correctly
        // the internal counter doesn't increase
        // and the handler is notified
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.events[1].name, "newSessionEvent")
        XCTAssertEqual(span.events[1].type, .performance)
        XCTAssertEqual(span.events[1].timestamp, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(span.events[1].attributes.count, 3)
        XCTAssertEqual(span.events[1].attributes["emb.type"] as! String, "perf")
        XCTAssertEqual(span.events[1].attributes["key1"] as! String, "value1")
        XCTAssertEqual(span.events[1].attributes["key2"] as! String, "value2")
        XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
        XCTAssertEqual(handler.createEventCallCount, 1)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 1)
    }

    func test_addSessionEvent_failure() throws {
        // given a span
        let span = testSpan

        // when adding a new event that would fail
        handler.createEventError = EmbraceOTelError.spanEventLimitReached("test")

        XCTAssertThrowsError(
            try span.addSessionEvent(
                name: "newSessionEvent",
                type: .performance,
                timestamp: Date(timeIntervalSince1970: 5),
                attributes: ["key1": "value1"],
                internalAttributes: ["key2": "value2"],
                isInternal: false
            )
        ) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -3)
            XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
            XCTAssertEqual(handler.createEventCallCount, 1)
            XCTAssertEqual(handler.onSpanEventAddedCallCount, 0)
        }
    }

    func test_addSessionEvent_internal() throws {
        // given a span
        let span = testSpan

        // when adding a new internal session event
        try span.addSessionEvent(
            name: "newSessionEvent",
            type: .performance,
            timestamp: Date(timeIntervalSince1970: 5),
            attributes: ["key1": "value1"],
            internalAttributes: ["key2": "value2"],
            isInternal: true
        )

        // then the event is added correctly
        // the internal counter increases
        // and the handler is notified
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.events[1].name, "newSessionEvent")
        XCTAssertEqual(span.events[1].type, .performance)
        XCTAssertEqual(span.events[1].timestamp, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(span.events[1].attributes.count, 3)
        XCTAssertEqual(span.events[1].attributes["emb.type"] as! String, "perf")
        XCTAssertEqual(span.events[1].attributes["key1"] as! String, "value1")
        XCTAssertEqual(span.events[1].attributes["key2"] as! String, "value2")
        XCTAssertEqual(span.state.safeValue.internalEventCount, 1)
        XCTAssertEqual(handler.createEventCallCount, 0)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 1)
    }

    func test_addLink_success() throws {
        // given a span
        let span = testSpan

        // when adding a new link
        try span.addLink(
            spanId: TestConstants.spanId,
            traceId: TestConstants.traceId,
            attributes: ["key": "value"]
        )

        // then the link is added correctly
        // the internal counter doesn't increase
        // and the handler is notified
        XCTAssertEqual(span.links.count, 2)
        XCTAssertEqual(span.links[1].context.spanId, TestConstants.spanId)
        XCTAssertEqual(span.links[1].context.traceId, TestConstants.traceId)
        XCTAssertEqual(span.links[1].attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalLinkCount, 0)
        XCTAssertEqual(handler.createLinkCallCount, 1)
        XCTAssertEqual(handler.onSpanLinkAddedCallCount, 1)
    }

    func test_addLink_failure() throws {
        // given a span
        let span = testSpan

        // when adding a new event that would fail
        handler.createLinkError = EmbraceOTelError.spanLinkLimitReached("test")

        XCTAssertThrowsError(
            try span.addLink(
                spanId: TestConstants.spanId,
                traceId: TestConstants.traceId,
                attributes: ["key": "value"]
            )
        ) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -4)
            XCTAssertEqual(span.state.safeValue.internalLinkCount, 0)
            XCTAssertEqual(handler.createLinkCallCount, 1)
            XCTAssertEqual(handler.onSpanLinkAddedCallCount, 0)
        }
    }

    func test_setAttribute_success() throws {
        // given a span
        let span = testSpan

        // when setting a new attribute
        try span.setAttribute(key: "key", value: "value")

        // then the attribute is set
        // the internal counter doesn't increase
        // and the handler is notified
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
        XCTAssertEqual(handler.validateAttributeCallCount, 1)
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 1)
    }

    func test_setAttribute_failure() throws {
        // given a span
        let span = testSpan

        // when setting a new attribute that would fail
        handler.validateAttributeError = EmbraceOTelError.spanAttributeLimitReached("test")

        XCTAssertThrowsError(try span.setAttribute(key: "key", value: "value")) { error in

            // then the correct error is thrown
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -5)
            XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
            XCTAssertEqual(handler.validateAttributeCallCount, 1)
            XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 0)
        }
    }

    func test_setAttribute_delete() throws {
        // given a span
        let span = testSpan

        // when deleting an attribute
        try span.setAttribute(key: "myKey", value: nil)

        // then the attribute is deleted
        // the internal counte doesn't change
        // and the handler is notified
        XCTAssertNil(span.attributes["myKey"])
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
        XCTAssertEqual(handler.validateAttributeCallCount, 1)
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 1)
    }

    func test_setInternalAttribute() throws {
        // given a span
        let span = testSpan

        // when setting a new attribute
        span.setInternalAttribute(key: "key", value: "value")

        // then the attribute is set
        // the internal counter increases
        // and the handler is notified
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 2)
        XCTAssertEqual(handler.validateAttributeCallCount, 0)
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 1)
    }

    func test_setInternalAttribute_delete() throws {
        // given a span
        let span = testSpan

        // when setting a new attribute
        span.setInternalAttribute(key: "key", value: "value")

        // then the attribute is set and the internal counter increases
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 2)

        // when deleting it
        span.setInternalAttribute(key: "key", value: nil)

        // then the attribute is deleted and the internal counter decreases
        XCTAssertNil(span.attributes["key"])
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)

        XCTAssertEqual(handler.validateAttributeCallCount, 0)
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 2)
    }

    func test_end() throws {
        // given a span
        let span = testSpan

        // when ending it
        let endTime = Date(timeIntervalSince1970: 9)
        span.end(endTime: endTime)

        // then the endTime is updated correctly
        // and the handler is notified
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(handler.onSpanEndedCallCount, 1)
    }

    func test_end_2() throws {
        // given a span
        let span = testSpan

        // when ending it
        span.end()

        // then the endTime is updated correctly
        // and the handler is notified
        XCTAssertNotNil(span.endTime)
        XCTAssertEqual(handler.onSpanEndedCallCount, 1)
    }
}
