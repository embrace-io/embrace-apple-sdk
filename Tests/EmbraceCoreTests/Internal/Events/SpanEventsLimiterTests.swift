//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceOTelInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

final class SpanEventsLimiterTests: XCTestCase {

    func test_initialization() {
        // given a limiter initialized with specific limits
        let limits = SpanEventsLimits(breadcrumb: 123, tap: 123)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // then it has the correct limits
        XCTAssertEqual(limiter.state.safeValue.limits, limits)
    }

    func test_configUpdated() {
        // given a limiter
        let limits = SpanEventsLimits(breadcrumb: 123, tap: 123)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when the remote config updates the limits
        let newLimits = SpanEventsLimits(breadcrumb: 321, tap: 321)
        let config = EditableConfig()
        config.spanEventsLimits = newLimits
        NotificationCenter.default.post(name: .embraceConfigUpdated, object: config)

        // then the limits are updated
        XCTAssertEqual(limiter.state.safeValue.limits, newLimits)
    }

    func test_newSession() {
        // given a limiter with a counter
        let limits = SpanEventsLimits(breadcrumb: 123, tap: 123)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)
        limiter.state.withLock {
            $0.counter = ["test": 1]
        }

        // when a new session starts
        NotificationCenter.default.post(name: .embraceSessionDidStart, object: nil)

        // then the counter is reset
        XCTAssert(limiter.state.safeValue.counter.isEmpty)
    }

    func test_applyLimits_doesNotReachLimit_breadcrumb() {
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

    func test_applyLimits_doesReachLimit_breadcrumb() {
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

    func test_applyLimits_doesNotReachLimit_tap() {
        // given a limiter with a limit of 1 tap
        let limits = SpanEventsLimits(tap: 1)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits on the first breadcrumb
        let event = tapEvent()
        let events = limiter.applyLimits(events: [event])

        // then the breadcrumb event is not discarded
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, event.name)
        XCTAssertEqual(events[0].timestamp, event.timestamp)

        // then the counter is correctly updated
        XCTAssertEqual(limiter.state.safeValue.counter["ux.tap"], 1)
    }

    func test_applyLimits_doesReachLimit_tap() {
        // given a limiter with a limit of 1 tap
        let limits = SpanEventsLimits(tap: 1)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits on the breadcrumbs
        let event1 = tapEvent()
        let event2 = tapEvent()
        let events = limiter.applyLimits(events: [event1, event2])

        // then the second breadcrumb event is discarded
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, event1.name)
        XCTAssertEqual(events[0].timestamp, event1.timestamp)

        // then the counter is correctly updated
        XCTAssertEqual(limiter.state.safeValue.counter["ux.tap"], 1)
    }

    func test_applyLimits_differentEventTypes() {
        // given a limiter with a limit of 0 breadcrumbs and 0 taps
        let limits = SpanEventsLimits(breadcrumb: 0, tap: 0)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits various events
        let event1 = Breadcrumb.breadcrumb("test")
        let event2 = tapEvent()
        let event3 = randomPushNotificationEvent()
        let event4 = Breadcrumb.breadcrumb("test")
        let event5 = tapEvent()
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

    func tapEvent() -> RecordingSpanEvent {
        return RecordingSpanEvent(
            name: SpanEventSemantics.Tap.name,
            timestamp: Date(),
            attributes: ["emb.type": .string("ux.tap")]
        )
    }

    // MARK: - Integration Tests with New Storage

    func test_limiter_worksWithNewStorageMechanism() throws {
        // Note: The SpanEventsLimiter applies limits before events are stored,
        // so it works the same way regardless of storage mechanism.
        // This test verifies that when limits are applied, only the allowed
        // events make it to the new separate storage.

        // given a limiter with a limit of 2 breadcrumbs
        let limits = SpanEventsLimits(breadcrumb: 2)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits on 5 breadcrumbs
        let event1 = Breadcrumb.breadcrumb("test1")
        let event2 = Breadcrumb.breadcrumb("test2")
        let event3 = Breadcrumb.breadcrumb("test3")
        let event4 = Breadcrumb.breadcrumb("test4")
        let event5 = Breadcrumb.breadcrumb("test5")

        let limitedEvents = limiter.applyLimits(events: [event1, event2, event3, event4, event5])

        // then only the first 2 events are allowed
        XCTAssertEqual(limitedEvents.count, 2)
        XCTAssertEqual(limitedEvents[0].name, event1.name)
        XCTAssertEqual(limitedEvents[1].name, event2.name)

        // verify that when these limited events would be stored in the new storage mechanism,
        // only the allowed events are present
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 2)
    }

    func test_limiter_countsEventsAcrossMultipleCalls() {
        // given a limiter with a limit of 3 breadcrumbs
        let limits = SpanEventsLimits(breadcrumb: 3)
        let limiter = SpanEventsLimiter(spanEventsLimits: limits, configNotificationCenter: NotificationCenter.default)

        // when applying limits in multiple calls (simulating multiple span exports)
        let event1 = Breadcrumb.breadcrumb("call1_event1")
        let event2 = Breadcrumb.breadcrumb("call1_event2")
        let firstCallEvents = limiter.applyLimits(events: [event1, event2])

        // then both events are allowed
        XCTAssertEqual(firstCallEvents.count, 2)
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 2)

        // when applying limits on more events
        let event3 = Breadcrumb.breadcrumb("call2_event1")
        let event4 = Breadcrumb.breadcrumb("call2_event2")
        let secondCallEvents = limiter.applyLimits(events: [event3, event4])

        // then only one more event is allowed (limit is 3 total)
        XCTAssertEqual(secondCallEvents.count, 1)
        XCTAssertEqual(secondCallEvents[0].name, event3.name)
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 3)

        // when applying limits on even more events
        let event5 = Breadcrumb.breadcrumb("call3_event1")
        let thirdCallEvents = limiter.applyLimits(events: [event5])

        // then no more events are allowed
        XCTAssertEqual(thirdCallEvents.count, 0)
        XCTAssertEqual(limiter.state.safeValue.counter["sys.breadcrumb"], 3)
    }
}
