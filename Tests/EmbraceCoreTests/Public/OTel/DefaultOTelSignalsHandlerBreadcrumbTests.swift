//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultOTelSignalsHandlerBreadcrumbTests: XCTestCase {

    var handler: DefaultOTelSignalsHandler!
    var sessionController: MockSessionController!
    var logController: LogController!
    var limiter: MockOTelSignalsLimiter!
    var sanitizer: MockOTelSignalsSanitizer!
    var bridge: MockOTelSignalBridge!
    var storage: EmbraceStorage!
    var upload: SpyEmbraceLogUploader!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        upload = SpyEmbraceLogUploader()

        sessionController = MockSessionController()
        sessionController.storage = storage

        logController = LogController(
            storage: storage,
            upload: upload,
            sessionController: sessionController,
            queue: .main
        )

        limiter = MockOTelSignalsLimiter()
        sanitizer = MockOTelSignalsSanitizer()
        bridge = MockOTelSignalBridge()

        handler = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: logController,
            limiter: limiter,
            sanitizer: sanitizer,
            bridge: bridge
        )

        sessionController.spanHandler = handler
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        storage = nil
        upload = nil
        sessionController = nil
        logController = nil
        limiter = nil
        sanitizer = nil
        bridge = nil
        handler = nil
    }

    func test_addBreadcrumb_success() throws {
        // given a handler with an active session
        // when adding a breadcrumb
        let timestamp = Date(timeIntervalSince1970: 5)
        try handler.addBreadcrumb("hello world", timestamp: timestamp)

        // then the event is added to the current session span with the correct values
        let span = sessionController.currentSessionSpan!
        XCTAssertEqual(span.events.count, 1)

        let event = span.events[0]
        XCTAssertEqual(event.name, "emb-breadcrumb")
        XCTAssertEqual(event.type, .breadcrumb)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["message"] as? String, "hello world")
        XCTAssertEqual(event.attributes["emb.type"] as? String, "sys.breadcrumb")

        // then the event is persisted on the session span
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.events.count, 1)
        XCTAssertEqual(record.events[0].name, "emb-breadcrumb")
        XCTAssertEqual(record.events[0].type, .breadcrumb)
        XCTAssertEqual(record.events[0].timestamp, timestamp)
        XCTAssertEqual(record.events[0].attributes["message"] as? String, "hello world")
        XCTAssertEqual(record.events[0].attributes["emb.type"] as? String, "sys.breadcrumb")
    }

    func test_addBreadcrumb_defaultTimestamp() throws {
        // given a handler with an active session
        // when adding a breadcrumb without an explicit timestamp
        let before = Date()
        try handler.addBreadcrumb("hello")
        let after = Date()

        // then the event timestamp falls within the call window
        let event = sessionController.currentSessionSpan!.events[0]
        XCTAssertGreaterThanOrEqual(event.timestamp, before)
        XCTAssertLessThanOrEqual(event.timestamp, after)
    }

    func test_addBreadcrumb_noSession_throws() throws {
        // given a handler with no active session
        let spanId = sessionController.currentSessionSpan!.context.spanId
        let traceId = sessionController.currentSessionSpan!.context.traceId
        sessionController.endSession()

        // when adding a breadcrumb
        XCTAssertThrowsError(try handler.addBreadcrumb("hello")) { error in

            // then it throws EmbraceOTelError.invalidSession
            XCTAssertEqual(error as? EmbraceOTelError, .invalidSession)

            // and no event is added to the (previous) session span
            let span = storage.fetchSpan(id: spanId, traceId: traceId)
            XCTAssertEqual(span!.events.count, 0)
        }
    }

    func test_addBreadcrumb_limitReached_throws() throws {
        // given a handler where the session-event limit will reject breadcrumbs
        limiter.shouldAddSessionEventReturnValue = false

        // when adding a breadcrumb
        XCTAssertThrowsError(try handler.addBreadcrumb("hello")) { error in

            // then it throws a span-event limit error
            XCTAssert(error is EmbraceOTelError)
            XCTAssertEqual((error as! EmbraceOTelError).errorCode, -3)

            // and no event is added to the session span
            let span = sessionController.currentSessionSpan!
            XCTAssertEqual(span.events.count, 0)
        }
    }
}
