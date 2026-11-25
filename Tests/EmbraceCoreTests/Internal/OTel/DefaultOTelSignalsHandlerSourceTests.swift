//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

/// Tests that the handler applies the limits and sanitization rules of each signal source,
/// using the real `DefaultOtelSignalsSanitizer` and `DefaultOtelSignalsLimiter`.
class DefaultOTelSignalsHandlerSourceTests: XCTestCase {

    var handler: DefaultOTelSignalsHandler!
    var sessionController: MockSessionController!
    var storage: EmbraceStorage!

    let longName = String(repeating: "n", count: 500)
    let longKey = String(repeating: "k", count: 500)
    let longValue = String(repeating: "v", count: 5000)

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        makeHandler()
    }

    override func tearDownWithError() throws {
        storage = nil
        sessionController = nil
        handler = nil
    }

    func makeHandler(sessionLimits: SessionLimits = SessionLimits()) {
        sessionController = MockSessionController()
        sessionController.storage = storage

        handler = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: nil,
            limiter: DefaultOtelSignalsLimiter(sessionLimits: sessionLimits),
            sanitizer: DefaultOtelSignalsSanitizer(sessionLimits: sessionLimits),
            bridge: MockOTelSignalBridge()
        )

        sessionController.spanHandler = handler
        sessionController.startSession(state: .foreground)
    }

    func createSpan(source: EmbraceOTelSignalSource, name: String = "span", attributes: EmbraceAttributes = [:]) throws -> EmbraceSpan {
        return try handler._createSpan(name: name, type: .performance, attributes: attributes, source: source)
    }

    // MARK: Truncation

    func test_captureService_spanIsNotTruncated() throws {
        // when a capture service creates a span with a long name and a long attribute
        let span = try createSpan(source: .captureService, name: longName, attributes: [longKey: longValue])

        // then nothing is truncated
        XCTAssertEqual(span.name, longName)
        XCTAssertEqual(span.attributes[longKey] as? String, longValue)
    }

    func test_user_spanIsTruncated() throws {
        // when a user creates a span with a long name and a long attribute
        let span = try createSpan(source: .user, name: longName, attributes: [longKey: longValue])

        // then the name, key and value are truncated
        XCTAssertEqual(span.name.count, 128)
        XCTAssertNil(span.attributes[longKey])
        XCTAssertEqual(span.attributes[String(longKey.prefix(128))] as? String, String(longValue.prefix(1024)))
    }

    func test_captureService_spanChangesAreNotTruncated() throws {
        // given a span created by a capture service
        let span = try createSpan(source: .captureService)

        // when adding a long attribute and a long event afterwards
        span.setAttribute(key: longKey, value: longValue)
        span.addEvent(name: longName, attributes: [longKey: longValue])

        // then nothing is truncated
        XCTAssertEqual(span.attributes[longKey] as? String, longValue)
        XCTAssertEqual(span.events.last?.name, longName)
        XCTAssertEqual(span.events.last?.attributes[longKey] as? String, longValue)
    }

    func test_user_spanChangesAreTruncated() throws {
        // given a span created by a user
        let span = try createSpan(source: .user)

        // when adding a long attribute and a long event afterwards
        span.setAttribute(key: longKey, value: longValue)
        span.addEvent(name: longName, attributes: [:])

        // then they are truncated
        XCTAssertNil(span.attributes[longKey])
        XCTAssertEqual(span.attributes[String(longKey.prefix(128))] as? String, String(longValue.prefix(1024)))
        XCTAssertEqual(span.events.last?.name.count, 128)
    }

    func test_captureService_sessionEventIsNotTruncated() throws {
        // when a capture service adds a session event with a long name and a long attribute
        let event = try handler._addSessionEvent(name: longName, attributes: [longKey: longValue], source: .captureService)

        // then nothing is truncated
        XCTAssertEqual(event?.name, longName)
        XCTAssertEqual(event?.attributes[longKey] as? String, longValue)
    }

    // MARK: Count limits

    func test_captureService_spanAttributeCountIsLimited() throws {
        // given a handler with a limit of 2 attributes for capture service spans
        makeHandler(sessionLimits: SessionLimits(captureService: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 2))))

        // when a capture service sets more attributes than the limit on its span
        let span = try createSpan(source: .captureService)
        span.setAttribute(key: "a", value: "1")
        span.setAttribute(key: "b", value: "2")
        span.setAttribute(key: "c", value: "3")

        // then the attributes over the limit are dropped
        XCTAssertNotNil(span.attributes["a"])
        XCTAssertNotNil(span.attributes["b"])
        XCTAssertNil(span.attributes["c"])
    }

    // MARK: Budgets

    func test_captureService_hasItsOwnSpanBudget() throws {
        // given a handler with a limit of 1 span for each source
        let oneSpan = SignalLimits(customSpans: SignalLimits.SpanLimits(count: 1))
        makeHandler(sessionLimits: SessionLimits(user: oneSpan, captureService: oneSpan))

        // when the user reaches its span limit
        _ = try createSpan(source: .user)
        XCTAssertThrowsError(try createSpan(source: .user))

        // then capture services can still create spans until they reach their own limit
        XCTAssertNoThrow(try createSpan(source: .captureService))
        XCTAssertThrowsError(try createSpan(source: .captureService))

        // and the SDK is never limited
        XCTAssertNoThrow(try createSpan(source: .sdk))
    }

    func test_captureService_hasItsOwnSessionEventBudget() throws {
        // given a handler with a limit of 1 session event for each source
        let oneEvent = SignalLimits(events: SignalLimits.SpanEventLimits(sessionSpanEventCount: 1))
        makeHandler(sessionLimits: SessionLimits(user: oneEvent, captureService: oneEvent))

        // when capture services reach their session event limit
        XCTAssertNotNil(try handler._addSessionEvent(name: "a", source: .captureService))
        XCTAssertThrowsError(try handler._addSessionEvent(name: "b", source: .captureService))

        // then users can still add session events
        XCTAssertNotNil(try handler._addSessionEvent(name: "c", source: .user))
    }

    // MARK: Span source

    func test_spans_keepTheirSource() throws {
        for source in [EmbraceOTelSignalSource.user, .captureService, .sdk] {
            let span = try createSpan(source: source)
            XCTAssertEqual((span as? DefaultEmbraceSpan)?.source, source)
        }
    }
}
