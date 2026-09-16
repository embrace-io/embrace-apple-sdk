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

    /// An open span. Spans stop accepting changes once they end, so the default fixture has to be
    /// open for any test that mutates it.
    var testSpan: DefaultEmbraceSpan {
        makeTestSpan()
    }

    /// A span that is already ended, for the tests that need one.
    var endedTestSpan: DefaultEmbraceSpan {
        makeTestSpan(endTime: Date(timeIntervalSince1970: 2))
    }

    func makeTestSpan(endTime: Date? = nil) -> DefaultEmbraceSpan {
        let context = EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId)
        let startTime = Date(timeIntervalSince1970: 1)
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
        let span = endedTestSpan

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
        span.addEvent(
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

        let result = span.addEvent(
            name: "newEvent",
            type: .performance,
            timestamp: Date(timeIntervalSince1970: 5),
            attributes: ["key": "value"]
        )

        // then nil is returned, the event isn't appended, and onSpanEventAdded isn't fired
        XCTAssertNil(result)
        XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
        XCTAssertEqual(handler.createEventCallCount, 1)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 0)
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
        span.addLink(
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

        // when adding a new link that would fail
        handler.createLinkError = EmbraceOTelError.spanLinkLimitReached("test")

        let result = span.addLink(
            spanId: TestConstants.spanId,
            traceId: TestConstants.traceId,
            attributes: ["key": "value"]
        )

        // then nil is returned, the link isn't appended, and onSpanLinkAdded isn't fired
        XCTAssertNil(result)
        XCTAssertEqual(span.state.safeValue.internalLinkCount, 0)
        XCTAssertEqual(handler.createLinkCallCount, 1)
        XCTAssertEqual(handler.onSpanLinkAddedCallCount, 0)
    }

    // MARK: link limit counter

    func test_addLink_countsLinksNotEvents() throws {
        // given a span that starts with 1 event and 1 link, with an extra event
        // added so the two counters can't coincide
        let span = testSpan
        span.addEvent(name: "extra")
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.links.count, 1)

        // when adding a new link
        span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        // then the count handed to the limiter is the number of links already
        // on the span, not the number of events
        XCTAssertEqual(handler.createLinkCurrentCount, 1)
    }

    func test_addLink_eventsDoNotConsumeTheLinkBudget() throws {
        // given a span with several events added on top of its initial event
        let span = testSpan
        for index in 0..<5 {
            span.addEvent(name: "event\(index)")
        }

        // when adding a link
        span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        // then the events are not counted against the link limit
        XCTAssertEqual(span.events.count, 6)
        XCTAssertEqual(handler.createLinkCurrentCount, 1)
    }

    func test_addLink_linksDoNotConsumeTheEventBudget() throws {
        // given a span with several links added on top of its initial link
        let span = testSpan
        for _ in 0..<5 {
            span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)
        }

        // when adding an event
        span.addEvent(name: "event")

        // then the links are not counted against the event limit
        XCTAssertEqual(span.links.count, 6)
        XCTAssertEqual(handler.createEventCurrentCount, 1)
    }

    func test_addLink_countGrowsWithEachAddedLink() throws {
        // given a span that starts with 1 link
        let span = testSpan

        // when adding links one after the other
        // then each call reports the number of links present at that point
        for expected in 1..<4 {
            XCTAssertNil(handler.createLinkError)
            span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)
            XCTAssertEqual(handler.createLinkCurrentCount, expected)
        }
    }

    // MARK: object overloads

    func test_addEvent_object_returnsStoredEvent() throws {
        let span = testSpan
        let input = EmbraceSpanEvent(
            name: "objectEvent",
            type: .performance,
            timestamp: Date(timeIntervalSince1970: 5),
            attributes: ["k": "v"]
        )

        let stored = span.addEvent(input)

        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.name, "objectEvent")
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(handler.createEventCallCount, 1)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 1)
    }

    func test_addEvent_object_returnsNil_whenLimitReached() throws {
        let span = testSpan
        handler.createEventError = EmbraceOTelError.spanEventLimitReached("test")

        let input = EmbraceSpanEvent(name: "objectEvent", attributes: ["k": "v"])
        let stored = span.addEvent(input)

        XCTAssertNil(stored)
        XCTAssertEqual(span.events.count, 1)  // unchanged
        XCTAssertEqual(handler.createEventCallCount, 1)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 0)
    }

    func test_addLink_object_returnsStoredLink() throws {
        let span = testSpan
        let input = EmbraceSpanLink(
            spanId: TestConstants.spanId,
            traceId: TestConstants.traceId,
            attributes: ["k": "v"]
        )

        let stored = span.addLink(input)

        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.context.spanId, TestConstants.spanId)
        XCTAssertEqual(span.links.count, 2)
        XCTAssertEqual(handler.createLinkCallCount, 1)
        XCTAssertEqual(handler.onSpanLinkAddedCallCount, 1)
    }

    func test_addLink_object_returnsNil_whenLimitReached() throws {
        let span = testSpan
        handler.createLinkError = EmbraceOTelError.spanLinkLimitReached("test")

        let input = EmbraceSpanLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)
        let stored = span.addLink(input)

        XCTAssertNil(stored)
        XCTAssertEqual(span.links.count, 1)  // unchanged
        XCTAssertEqual(handler.createLinkCallCount, 1)
        XCTAssertEqual(handler.onSpanLinkAddedCallCount, 0)
    }

    func test_setAttribute_success() throws {
        // given a span
        let span = testSpan

        // when setting a new attribute
        span.setAttribute(key: "key", value: "value")

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
        span.setAttribute(key: "key", value: "value")

        // then the attribute is not set
        XCTAssertNotEqual(span.attributes["key"] as? String, "value")
    }

    func test_setAttribute_delete() throws {
        // given a span
        let span = testSpan

        // when deleting an attribute
        span.setAttribute(key: "myKey", value: nil)

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

    // MARK: ended spans reject changes

    func test_end_secondCallIsIgnored() throws {
        // given a span that already ended
        let span = testSpan
        let endTime = Date(timeIntervalSince1970: 9)
        span.end(endTime: endTime)

        // when ending it again
        span.end(endTime: Date(timeIntervalSince1970: 20))

        // then the original end time is kept and the handler is not notified again
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(handler.onSpanEndedCallCount, 1)
    }

    func test_setStatus_afterEnd_isIgnored() throws {
        // given a span that ended with a status
        let span = testSpan
        span.setStatus(.ok)
        span.end()

        // when updating the status afterwards
        span.setStatus(.error)

        // then the status is unchanged and nothing is written through
        XCTAssertEqual(span.status, .ok)
        XCTAssertEqual(handler.onSpanStatusUpdatedCallCount, 1)
    }

    func test_setAttribute_afterEnd_isIgnored() throws {
        // given a span that ended
        let span = testSpan
        span.end()

        // when setting an attribute afterwards
        span.setAttribute(key: "key", value: "value")

        // then it isn't stored and nothing is written through
        XCTAssertNil(span.attributes["key"])
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 0)
    }

    func test_addEvent_afterEnd_isIgnored() throws {
        // given a span that ended
        let span = testSpan
        let eventCount = span.events.count
        span.end()

        // when adding an event afterwards
        let result = span.addEvent(name: "newEvent")

        // then nothing is added and nothing is written through
        XCTAssertNil(result)
        XCTAssertEqual(span.events.count, eventCount)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 0)
    }

    func test_addLink_afterEnd_isIgnored() throws {
        // given a span that ended
        let span = testSpan
        let linkCount = span.links.count
        span.end()

        // when adding a link afterwards
        let result = span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        // then nothing is added and nothing is written through
        XCTAssertNil(result)
        XCTAssertEqual(span.links.count, linkCount)
        XCTAssertEqual(handler.onSpanLinkAddedCallCount, 0)
    }

    func test_endWithErrorCode_afterEnd_keepsTheOriginalOutcome() throws {
        // given a span that ended successfully
        let span = testSpan
        span.end(errorCode: nil, endTime: Date(timeIntervalSince1970: 9))

        // when ending it again with an error code, as auto termination would
        span.end(errorCode: .userAbandon, endTime: Date(timeIntervalSince1970: 20))

        // then the span is still reported as successful
        XCTAssertEqual(span.status, .ok)
        XCTAssertNil(span.attributes[SpanSemantics.keyErrorCode])
        XCTAssertEqual(span.endTime, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(handler.onSpanEndedCallCount, 1)
    }

    func test_spanCreatedWithEndTime_rejectsChanges() throws {
        // given a span created already ended
        let span = endedTestSpan

        // when trying to change it
        span.setAttribute(key: "key", value: "value")
        span.setStatus(.ok)

        // then nothing is written through
        XCTAssertNil(span.attributes["key"])
        XCTAssertEqual(handler.onSpanAttributesUpdatedCallCount, 0)
        XCTAssertEqual(handler.onSpanStatusUpdatedCallCount, 0)
    }
}
