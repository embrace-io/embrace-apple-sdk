//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfigInternal
import EmbraceConfiguration
import TestSupport
import XCTest

@testable import EmbraceCore

final class SpanEventsLimiterTests: XCTestCase {

    func test_initialization() {
        // given a limiter initialized with specific limits
        let limits = SpanEventsLimits(breadcrumb: 123)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // then it has the correct limits
        XCTAssertEqual(limiter.state.safeValue.limits, limits)
    }

    func test_configUpdated() {
        // given a limiter
        let limits = SpanEventsLimits(breadcrumb: 123)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when the remote config updates the limits
        let newLimits = SpanEventsLimits(breadcrumb: 321)
        let config = EditableConfig()
        config.spanEventsLimits = newLimits
        NotificationCenter.default.post(name: .embraceConfigUpdated, object: config)

        // then the limits are updated
        XCTAssertEqual(limiter.state.safeValue.limits, newLimits)
    }

    func test_newSession() {
        // given a limiter with a counter
        let limits = SpanEventsLimits(breadcrumb: 123)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)
        limiter.state.withLock {
            $0.counter = ["test": 1]
        }

        // when a new session starts
        NotificationCenter.default.post(name: .embraceSessionDidStart, object: nil)

        // then the counter is reset
        XCTAssert(limiter.state.safeValue.counter.isEmpty)
    }

    func test_applyLimits_doesNotReachLimit() {
        // given a limiter with a limit of 1 breadcrumb
        let limits = SpanEventsLimits(breadcrumb: 1)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits on the first breadcrumb
        let event = Breadcrumb.breadcrumb("test")
        let added = limiter.shouldAddEvent(event: event)

        // then the breadcrumb event is not discarded
        XCTAssertTrue(added)

        // then the counter is correctly updated
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 1)
    }

    func test_applyLimits_doesReachLimit() {
        // given a limiter with a limit of 1 breadcrumb
        let limits = SpanEventsLimits(breadcrumb: 1)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits on the first breadcrumb
        let event1 = Breadcrumb.breadcrumb("test1")
        var added = limiter.shouldAddEvent(event: event1)

        // then the breadcrumb event is not discarded
        XCTAssertTrue(added)

        // when applying limits on the second breadcrumb
        let event2 = Breadcrumb.breadcrumb("test2")
        added = limiter.shouldAddEvent(event: event2)

        // then the second breadcrumb event is discarded
        XCTAssertFalse(added)

        // then the counter is correctly updated
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 1)
    }

    func test_applyLimits_differentEventTypes() {
        // given a limiter with a limit of 0 breadcrumbs
        let limits = SpanEventsLimits(breadcrumb: 0)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits various events
        // then only the breadcrumb events are dropped
        XCTAssertFalse(limiter.shouldAddEvent(event: Breadcrumb.breadcrumb("test")))
        XCTAssertFalse(limiter.shouldAddEvent(event: Breadcrumb.breadcrumb("test")))
        XCTAssertTrue(limiter.shouldAddEvent(event: randomPushNotificationEvent()))
        XCTAssertFalse(limiter.shouldAddEvent(event: Breadcrumb.breadcrumb("test")))
        XCTAssertFalse(limiter.shouldAddEvent(event: Breadcrumb.breadcrumb("test")))
    }

    func randomPushNotificationEvent() -> PushNotificationEvent {
        let validPayload: [AnyHashable: Any] = [
            PushNotificationEvent.Constants.apsRootKey: [
                PushNotificationEvent.Constants.apsAlert: [
                    PushNotificationEvent.Constants.apsTitle: "title",
                    PushNotificationEvent.Constants.apsSubtitle: "subtitle",
                    PushNotificationEvent.Constants.apsBody: "body"
                ],
                PushNotificationEvent.Constants.apsCategory: "category",
                PushNotificationEvent.Constants.apsBadge: 1
            ]
        ]

        let event = try? PushNotificationEvent(userInfo: validPayload)
        return event!
    }
}
