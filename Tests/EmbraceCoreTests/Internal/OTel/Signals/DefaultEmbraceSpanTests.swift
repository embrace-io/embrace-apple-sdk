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

    /// A span with no preexisting events, links or attributes, so limits can be
    /// asserted against the number of calls made by the test.
    var emptyTestSpan: DefaultEmbraceSpan {
        DefaultEmbraceSpan(
            context: EmbraceSpanContext(spanId: TestConstants.spanId, traceId: TestConstants.traceId),
            name: "name",
            startTime: Date(timeIntervalSince1970: 1),
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
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 1)
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
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 1)
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
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 1)
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
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 2)
    }

    func test_setInternalAttribute_sameKeyTwice_doesNotInflateCount() throws {
        // given a span
        let span = testSpan

        // when setting the same internal attribute twice
        span.setInternalAttribute(key: "key", value: "value")
        span.setInternalAttribute(key: "key", value: "otherValue")

        // then the internal counter only counts the attribute once
        XCTAssertEqual(span.attributes["key"] as! String, "otherValue")
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 2)
    }

    func test_setInternalAttribute_deleteMissingKey_doesNotDecreaseCount() throws {
        // given a span
        let span = testSpan

        // when deleting an internal attribute that was never set
        span.setInternalAttribute(key: "missingKey", value: nil)

        // then the internal counter is left alone
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
    }

    // MARK: concurrency

    func test_addLink_concurrent_keepsEveryLink() throws {
        // given a span with nothing on it
        let span = emptyTestSpan

        // when adding links from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.addLink(spanId: "spanId\(index)", traceId: "traceId\(index)")
        }

        // then no link is lost
        XCTAssertEqual(span.links.count, 1000)
    }

    func test_addLink_concurrent_withRaisedLimit_keepsEveryLink() throws {
        // given a span with a link limit well above the number of links being added
        let span = emptyTestSpan
        handler.createLinkLimit = 5000

        // when adding links from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.addLink(spanId: "spanId\(index)", traceId: "traceId\(index)")
        }

        // then every link is present, and none of them is a duplicate of another
        XCTAssertEqual(span.links.count, 1000)

        let spanIds = Set(span.links.map { $0.context.spanId })
        XCTAssertEqual(spanIds.count, 1000)
    }

    func test_addLink_concurrent_stopsExactlyAtTheLimit() throws {
        // given a span with a link limit below the number of links being added
        let span = emptyTestSpan
        handler.createLinkLimit = 50

        // when adding links from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.addLink(spanId: "spanId\(index)", traceId: "traceId\(index)")
        }

        // then the limit is honored exactly, with no extra links slipping through
        XCTAssertEqual(span.links.count, 50)
    }

    func test_addEvent_concurrent_keepsEveryEvent() throws {
        // given a span with nothing on it
        let span = emptyTestSpan

        // when adding events from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.addEvent(name: "event\(index)")
        }

        // then no event is lost
        XCTAssertEqual(span.events.count, 1000)
    }

    func test_addEvent_concurrent_stopsExactlyAtTheLimit() throws {
        // given a span with an event limit below the number of events being added
        let span = emptyTestSpan
        handler.createEventLimit = 50

        // when adding events from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.addEvent(name: "event\(index)")
        }

        // then the limit is honored exactly, with no extra events slipping through
        XCTAssertEqual(span.events.count, 50)
    }

    func test_addEvent_concurrent_internalEventsIgnoreTheLimit() throws {
        // given a span with an event limit below the number of events being added
        let span = emptyTestSpan
        handler.createEventLimit = 50

        // when adding internal and non internal events from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            if index.isMultiple(of: 2) {
                try? span._addEvent(name: "internal\(index)", isInternal: true)
            } else {
                span.addEvent(name: "event\(index)")
            }
        }

        // then every internal event is kept, the limited ones stop at the limit,
        // and the internal counter matches the internal events actually stored
        XCTAssertEqual(span.state.safeValue.internalEventCount, 500)
        XCTAssertEqual(span.events.count, 550)
    }

    func test_setAttribute_concurrent_keepsEveryAttribute() throws {
        // given a span with nothing on it
        let span = emptyTestSpan

        // when setting different attributes from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.setAttribute(key: "key\(index)", value: "value\(index)")
        }

        // then no attribute is lost, and the handler is notified once per update
        XCTAssertEqual(span.attributes.count, 1000)
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 1000)

        for index in 0..<1000 {
            XCTAssertEqual(span.attributes["key\(index)"] as? String, "value\(index)")
        }
    }

    func test_setAttribute_concurrent_stopsExactlyAtTheLimit() throws {
        // given a span with an attribute limit below the number of attributes being set
        let span = emptyTestSpan
        handler.validateAttributeLimit = 50

        // when setting different attributes from multiple threads at once
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            span.setAttribute(key: "key\(index)", value: "value\(index)")
        }

        // then the limit is honored exactly, with no extra attributes slipping through
        XCTAssertEqual(span.attributes.count, 50)
    }

    func test_concurrent_mixedMutations_doNotClobberEachOther() throws {
        // given a span with nothing on it
        let span = emptyTestSpan
        let endTime = Date(timeIntervalSince1970: 9)

        // when every kind of mutation runs from multiple threads at once.
        // Ending is left out of the mix: an ended span refuses further changes, so a concurrent
        // end would make missing mutations indistinguishable from correctly refused ones.
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            switch index % 4 {
            case 0:
                span.setStatus(.ok)
            case 1:
                span.addEvent(name: "event\(index)")
            case 2:
                span.addLink(spanId: "spanId\(index)", traceId: "traceId\(index)")
            default:
                span.setAttribute(key: "key\(index)", value: "value\(index)")
            }
        }

        span.end(endTime: endTime)

        // then no mutation is lost to another one
        XCTAssertEqual(span.status, .ok)
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.events.count, 250)
        XCTAssertEqual(span.links.count, 250)
        XCTAssertEqual(span.attributes.count, 250)
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
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 0)
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
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 0)
        XCTAssertEqual(handler.onSpanStatusUpdatedCallCount, 0)
    }

    func test_setInternalAttribute_afterEnd_isIgnored() throws {
        // given a span that ended
        let span = testSpan
        span.end()

        // when the SDK itself writes an attribute afterwards
        span.setInternalAttribute(key: "internalKey", value: "value")

        // then it isn't stored and nothing is written through
        XCTAssertNil(span.attributes["internalKey"])
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 0)
    }

    func test_end_concurrent_onlyOneCallWinsAndTheHandlerIsNotifiedOnce() throws {
        // given an open span
        let span = testSpan

        // when many threads end it at the same time, each with a different end time
        let endTimes = (0..<100).map { Date(timeIntervalSince1970: Double(100 + $0)) }
        DispatchQueue.concurrentPerform(iterations: endTimes.count) { index in
            span.end(endTime: endTimes[index])
        }

        // then only one of them takes effect
        XCTAssertEqual(handler.onSpanEndedCallCount, 1)

        // and the span kept exactly the end time the handler was notified with,
        // so the stored span and the exported one can't disagree
        let reported = try XCTUnwrap(handler.onSpanEndedTimes.first)
        XCTAssertEqual(span.endTime, reported)
        XCTAssertTrue(endTimes.contains(reported))
    }

    func test_end_concurrent_withErrorCode_neverLeavesAPartialOutcome() throws {
        for _ in 0..<2000 {
            // given an open span with no outcome yet
            let span = makeTestSpan()
            span.setStatus(.unset)

            // when it is ended with an error code and plainly at the same time
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async {
                span.end(errorCode: .userAbandon, endTime: Date(timeIntervalSince1970: 10))
                group.leave()
            }
            span.end(endTime: Date(timeIntervalSince1970: 20))
            group.wait()

            // then either the error-code end won and the span is fully marked as failed, or the
            // plain end won and none of that outcome is present. Never half of it.
            if span.attributes[SpanSemantics.keyErrorCode] != nil {
                XCTAssertEqual(span.status, .error)
            }
        }
    }

    func test_addSessionEvent_afterEnd_isIgnored() throws {
        // given a span that ended
        let span = testSpan
        let eventCount = span.events.count
        span.end()

        // when the SDK itself adds a session event afterwards
        let result = try span.addSessionEvent(name: "sessionEvent", isInternal: true)

        // then nothing is added and nothing is written through
        XCTAssertNil(result)
        XCTAssertEqual(span.events.count, eventCount)
        XCTAssertEqual(handler.onSpanEventAddedCallCount, 0)
    }
}
