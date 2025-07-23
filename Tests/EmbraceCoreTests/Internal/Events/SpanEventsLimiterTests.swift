//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceOTelInternal
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
        let events = limiter.applyLimits(events: [event])

        // then the breadcrumb event is not discarded
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, event.name)
        XCTAssertEqual(events[0].timestamp, event.timestamp)

        // then the counter is correctly updated
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 1)
    }

    func test_applyLimits_doesReachLimit() {
        // given a limiter with a limit of 1 breadcrumb
        let limits = SpanEventsLimits(breadcrumb: 1)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits on the breadcrumbs
        let event1 = Breadcrumb.breadcrumb("test1")
        let event2 = Breadcrumb.breadcrumb("test2")
        let events = limiter.applyLimits(events: [event1, event2])

        // then the second breadcrumb event is discarded
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, event1.name)
        XCTAssertEqual(events[0].timestamp, event1.timestamp)

        // then the counter is correctly updated
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 1)
    }

    func test_applyLimits_differentEventTypes() {
        // given a limiter with a limit of 0 breadcrumbs
        let limits = SpanEventsLimits(breadcrumb: 0)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits various events
        let event1 = Breadcrumb.breadcrumb("test")
        let event2 = Breadcrumb.breadcrumb("test")
        let event3 = randomPushNotificationEvent()
        let event4 = Breadcrumb.breadcrumb("test")
        let event5 = Breadcrumb.breadcrumb("test")
        let events = limiter.applyLimits(events: [event1, event2, event3, event4, event5])

        // then the breadcrumb events are dropped
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, event3.name)
        XCTAssertEqual(events[0].timestamp, event3.timestamp)
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
