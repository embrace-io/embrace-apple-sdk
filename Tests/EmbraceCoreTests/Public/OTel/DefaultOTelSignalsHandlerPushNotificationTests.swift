//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultOTelSignalsHandlerPushNotificationTests: XCTestCase {

    var handler: DefaultOTelSignalsHandler!
    var sessionController: MockSessionController!
    var logController: LogController!
    var limiter: MockOTelSignalsLimiter!
    var sanitizer: MockOTelSignalsSanitizer!
    var bridge: MockOTelSignalBridge!
    var storage: EmbraceStorage!
    var upload: SpyEmbraceLogUploader!

    // MARK: Fixtures

    /// Standard notification payload with plain alert strings, category and badge.
    let fullPayload: [AnyHashable: Any] = [
        "aps": [
            "alert": [
                "title": "title",
                "subtitle": "subtitle",
                "body": "body"
            ],
            "category": "category",
            "badge": 1
        ]
    ]

    /// Notification payload with localized alert keys (title-loc-key, etc).
    let localizedPayload: [AnyHashable: Any] = [
        "aps": [
            "alert": [
                "title-loc-key": "loc-title",
                "subtitle-loc-key": "loc-subtitle",
                "body-loc-key": "loc-body"
            ]
        ]
    ]

    /// Silent push payload (content-available = 1).
    let silentPayload: [AnyHashable: Any] = [
        "aps": [
            "content-available": 1
        ]
    ]

    // MARK: setup/teardown

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

    // MARK: success path

    func test_addPushNotificationEvent_success_captureData() throws {
        // given a handler with an active session
        // when adding a push notification event with data capture enabled
        let timestamp = Date(timeIntervalSince1970: 5)
        handler.addPushNotificationEvent(
            userInfo: fullPayload,
            timestamp: timestamp,
            attributes: ["key": "value"],
            captureData: true
        )

        // then the event is added to the session span with the parsed attributes
        let span = sessionController.currentSessionSpan!
        XCTAssertEqual(span.events.count, 1)

        let event = span.events[0]
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.type, .pushNotification)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["emb.type"] as? String, "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"] as? String, "notif")
        XCTAssertEqual(event.attributes["notification.title"] as? String, "title")
        XCTAssertEqual(event.attributes["notification.subtitle"] as? String, "subtitle")
        XCTAssertEqual(event.attributes["notification.body"] as? String, "body")
        XCTAssertEqual(event.attributes["notification.category"] as? String, "category")
        XCTAssertEqual(event.attributes["notification.badge"] as? String, "1")
        XCTAssertEqual(event.attributes["key"] as? String, "value")
    }

    func test_addPushNotificationEvent_success_localizedAlert() throws {
        // given a handler with an active session
        // when adding a push notification event whose alert uses localized keys
        handler.addPushNotificationEvent(userInfo: localizedPayload, captureData: true)

        // then the localized keys are picked up for title/subtitle/body
        let event = sessionController.currentSessionSpan!.events[0]
        XCTAssertEqual(event.attributes["notification.title"] as? String, "loc-title")
        XCTAssertEqual(event.attributes["notification.subtitle"] as? String, "loc-subtitle")
        XCTAssertEqual(event.attributes["notification.body"] as? String, "loc-body")
    }

    func test_addPushNotificationEvent_success_captureDataDisabled() throws {
        // given a handler with an active session
        // when adding a push notification event with data capture disabled
        handler.addPushNotificationEvent(userInfo: fullPayload, captureData: false)

        // then only the type attributes are set
        let event = sessionController.currentSessionSpan!.events[0]
        XCTAssertEqual(event.attributes["emb.type"] as? String, "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"] as? String, "notif")
        XCTAssertNil(event.attributes["notification.title"])
        XCTAssertNil(event.attributes["notification.subtitle"])
        XCTAssertNil(event.attributes["notification.body"])
        XCTAssertNil(event.attributes["notification.category"])
        XCTAssertNil(event.attributes["notification.badge"])
    }

    func test_addPushNotificationEvent_success_silent() throws {
        // given a handler with an active session
        // when adding a silent push notification event
        handler.addPushNotificationEvent(userInfo: silentPayload, captureData: true)

        // then the notification type is reported as silent
        let event = sessionController.currentSessionSpan!.events[0]
        XCTAssertEqual(event.attributes["notification.type"] as? String, "silent")
    }

    func test_addPushNotificationEvent_defaultTimestamp() throws {
        // given a handler with an active session
        // when adding a push notification event without an explicit timestamp
        let before = Date()
        handler.addPushNotificationEvent(userInfo: fullPayload)
        let after = Date()

        // then the event timestamp falls within the call window
        let event = sessionController.currentSessionSpan!.events[0]
        XCTAssertGreaterThanOrEqual(event.timestamp, before)
        XCTAssertLessThanOrEqual(event.timestamp, after)
    }

    // MARK: error paths

    func test_addPushNotificationEvent_invalidPayload_throws() throws {
        // given a handler with an active session
        // when adding a push notification event with a payload missing the aps root
        handler.addPushNotificationEvent(userInfo: ["foo": "bar"])

        // then no event is added to the session span
        XCTAssertEqual(self.sessionController.currentSessionSpan!.events.count, 0)
    }

    func test_addPushNotificationEvent_noSession_throws() throws {
        // given a handler with no active session
        let spanId = sessionController.currentSessionSpan!.context.spanId
        let traceId = sessionController.currentSessionSpan!.context.traceId
        sessionController.endSession()

        // when adding a push notification event
        handler.addPushNotificationEvent(userInfo: fullPayload)

        // then no event is added to the (previous) session span
        let span = storage.fetchSpan(id: spanId, traceId: traceId)
        XCTAssertEqual(span!.events.count, 0)
    }

    func test_addPushNotificationEvent_limitReached_throws() throws {
        // given a handler where the session-event limit will reject events
        limiter.shouldAddSessionEventReturnValue = false

        // when adding a push notification event
        handler.addPushNotificationEvent(userInfo: fullPayload)

        // then no event is added to the session span
        XCTAssertEqual(self.sessionController.currentSessionSpan!.events.count, 0)
    }

    // MARK: attribute collisions

    func test_addPushNotificationEvent_attributeCollision() throws {
        // given a handler with an active session
        // when adding a push notification event with attributes that collide with internal ones
        handler.addPushNotificationEvent(
            userInfo: fullPayload,
            attributes: [
                "emb.type": "test",
                "notification.type": "test"
            ],
            captureData: true
        )

        // then the internal attributes are kept
        let event = sessionController.currentSessionSpan!.events[0]
        XCTAssertEqual(event.attributes["emb.type"] as? String, "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"] as? String, "notif")
    }
}
