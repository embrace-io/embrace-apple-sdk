//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultEmbraceSpanSourceTests: XCTestCase {

    var handler: MockEmbraceSpanHandler!

    override func setUpWithError() throws {
        handler = MockEmbraceSpanHandler()
    }

    override func tearDownWithError() throws {
        handler = nil
    }

    /// An open span. Spans stop accepting changes once they end, so the fixture has to be open for
    /// any test that mutates it.
    func makeTestSpan(source: EmbraceOTelSignalSource) -> DefaultEmbraceSpan {
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
            events: [event],
            links: [link],
            attributes: ["myKey": "myValue"],
            internalAttributeCount: 1,
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId,
            autoTerminationCode: .failure,
            source: source,
            handler: handler
        )
    }

    // MARK: SDK

    func test_sdk_addEvent_skipsHandlerValidation() throws {
        // given a span created by the SDK
        let span = makeTestSpan(source: .sdk)

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

    func test_sdk_setAttribute_skipsHandlerValidation() throws {
        // given a span created by the SDK
        let span = makeTestSpan(source: .sdk)

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

    func test_sdk_setAttributeWithUserSource_usesHandlerValidation() throws {
        // given a span created by the SDK
        let span = makeTestSpan(source: .sdk)

        // when setting an attribute that comes from the user
        span.setAttribute(key: "key", value: "value", source: .user)

        // then the attribute is validated with the user rules
        // and it doesn't count as an internal attribute
        XCTAssertEqual(span.attributes["key"] as! String, "value")
        XCTAssertEqual(handler.validateAttributeCallCount, 1)
        XCTAssertEqual(handler.validateAttributeSource, .user)
        XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
        XCTAssertEqual(handler.onSpanAttributeUpdatedCallCount, 1)
    }

    func test_sdk_addLink_passesSourceToHandler() throws {
        // given a span created by the SDK
        let span = makeTestSpan(source: .sdk)

        // when adding a link
        span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

        // then the handler validates it with the SDK source
        XCTAssertEqual(handler.createLinkCallCount, 1)
        XCTAssertEqual(handler.createLinkSource, .sdk)
    }

    // MARK: Capture services and users

    func test_addEvent_passesSpanSourceToHandler() throws {
        for source in [EmbraceOTelSignalSource.user, .captureService] {
            // given a span created by the source
            handler = MockEmbraceSpanHandler()
            let span = makeTestSpan(source: source)

            // when adding an event
            span.addEvent(name: "newEvent")

            // then the handler validates it with the span's source
            // and the event is not counted as internal
            XCTAssertEqual(handler.createEventCallCount, 1)
            XCTAssertEqual(handler.createEventSource, source)
            XCTAssertEqual(span.state.safeValue.internalEventCount, 0)
        }
    }

    func test_addLink_passesSpanSourceToHandler() throws {
        for source in [EmbraceOTelSignalSource.user, .captureService] {
            // given a span created by the source
            handler = MockEmbraceSpanHandler()
            let span = makeTestSpan(source: source)

            // when adding a link
            span.addLink(spanId: TestConstants.spanId, traceId: TestConstants.traceId)

            // then the handler validates it with the span's source
            XCTAssertEqual(handler.createLinkCallCount, 1)
            XCTAssertEqual(handler.createLinkSource, source)
        }
    }

    func test_setAttribute_passesSpanSourceToHandler() throws {
        for source in [EmbraceOTelSignalSource.user, .captureService] {
            // given a span created by the source
            handler = MockEmbraceSpanHandler()
            let span = makeTestSpan(source: source)

            // when setting an attribute
            span.setAttribute(key: "key", value: "value")

            // then the handler validates it with the span's source
            // and the attribute counts towards the span's attribute limit
            XCTAssertEqual(handler.validateAttributeCallCount, 1)
            XCTAssertEqual(handler.validateAttributeSource, source)
            XCTAssertEqual(span.state.safeValue.internalAttributeCount, 1)
        }
    }
}
