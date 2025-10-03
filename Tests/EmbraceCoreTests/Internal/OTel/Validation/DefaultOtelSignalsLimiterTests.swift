//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultOtelSignalsLimiterTests: XCTestCase {

    func test_reset() throws {
        // given a limiter
        let limiter = DefaultOtelSignalsLimiter()

        // when it has some active counters
        limiter.state.withLock {
            $0.customSpanCounter = 10
            $0.eventCounter = 10
            $0.eventTypeCounter["test"] = 10
            $0.linkCounter = 10
            $0.logCounter[1] = 10
        }

        // when resetting the counters
        limiter.reset()

        // then the counters are reset
        XCTAssertEqual(limiter.state.safeValue.customSpanCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.eventCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter.count, 0)
        XCTAssertEqual(limiter.state.safeValue.linkCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.logCounter.count, 0)
    }

    func test_configUpdate() throws {
        // given a limiter
        let limiter = DefaultOtelSignalsLimiter()

        // when the config is updated
        let config = EditableConfig()
        config.spanEventTypeLimits = SpanEventTypeLimits(breadcrumb: 5)
        config.logSeverityLimits = LogSeverityLimits(info: 1, warning: 2, error: 3)
        NotificationCenter.default.post(name: .embraceConfigUpdated, object: config)

        // then the limits are updated
        XCTAssertEqual(limiter.state.safeValue.limits.events.typeLimits, config.spanEventTypeLimits)
        XCTAssertEqual(limiter.state.safeValue.limits.logs.severityLimits, config.logSeverityLimits)
    }

    func test_shouldCreateCustomSpan_success() throws {
        // given a limiter with a limit of custom spans
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(count: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a custom span that wouldn't reach the limit
        let result = limiter.shouldCreateCustomSpan()

        // then the span should be allowed to be created and the counter should increase
        XCTAssertTrue(result)
        XCTAssertEqual(limiter.state.safeValue.customSpanCounter, 1)
    }

    func test_shouldCreateCustomSpan_failure() throws {
        // given a limiter with a limit of custom spans
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(count: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a custom span that would reach the limit
        limiter.state.safeValue.customSpanCounter = 5
        let result = limiter.shouldCreateCustomSpan()

        // then the span should not be allowed to be created and the counter should not change
        XCTAssertFalse(result)
        XCTAssertEqual(limiter.state.safeValue.customSpanCounter, 5)
    }

    func test_shouldAddSessionEvent_success() throws {
        // given a limiter with a limit of 5 breadcrumbs
        let limiter = DefaultOtelSignalsLimiter(spanEventTypeLimits: SpanEventTypeLimits(breadcrumb: 5))

        // when creating a new breadcrumb that wouldn't reach the limit
        let result = limiter.shouldAddSessionEvent(ofType: .breadcrumb)

        // then the event should be allowed to be created and the counter should increase
        XCTAssertTrue(result)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter["sys.breadcrumb"], 1)
    }

    func test_shouldAddSessionEvent_failure() throws {
        // given a limiter with a limit of 5 breadcrumbs
        let limiter = DefaultOtelSignalsLimiter(spanEventTypeLimits: SpanEventTypeLimits(breadcrumb: 5))

        // when creating a new breadcrumb that would reach the limit
        limiter.state.safeValue.eventCounter = 5
        limiter.state.safeValue.eventTypeCounter["sys.breadcrumb"] = 5
        let result = limiter.shouldAddSessionEvent(ofType: .breadcrumb)

        // then the event should not be allowed to be created and the counter should not increase
        XCTAssertFalse(result)
        XCTAssertEqual(limiter.state.safeValue.eventCounter, 5)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter["sys.breadcrumb"], 5)
    }

    func test_shouldAddSessionEvent_emptyType() throws {
        // given a limiter
        let limiter = DefaultOtelSignalsLimiter()

        // when creating a new event with an empty type that wouldn't reach the limit
        let result = limiter.shouldAddSessionEvent(ofType: nil)

        // then the event should be allowed to be created and the counter should increase
        XCTAssertTrue(result)
        XCTAssertEqual(limiter.state.safeValue.eventCounter, 1)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter["__emb.empty__"], 1)
    }

    func test_shouldAddSessionEvent_totalLimit() throws {
        // given a limiter with a total limit of 5 session span events
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(sessionSpanEventCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new event that would reach the limit
        limiter.state.safeValue.eventCounter = 5
        limiter.state.safeValue.eventTypeCounter = [
            "__emb.empty__": 2,
            "sys.breadrcumb": 2,
            "sys.push_notification": 1
        ]
        let result = limiter.shouldAddSessionEvent(ofType: nil)

        // then the event should not be allowed to be created and the counter should not increase
        XCTAssertFalse(result)
        XCTAssertEqual(limiter.state.safeValue.eventCounter, 5)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter["__emb.empty__"], 2)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter["sys.breadrcumb"], 2)
        XCTAssertEqual(limiter.state.safeValue.eventTypeCounter["sys.push_notification"], 1)
    }

    func test_shouldCreateLog_success() throws {
        // given a limiter with a limit of 5 logs for each severity
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 5, warning: 5, error: 5))

        // when creating a log for each severity that wouldn't reach the limit
        let result1 = limiter.shouldCreateLog(type: .message, severity: .info)
        let result2 = limiter.shouldCreateLog(type: .message, severity: .warn)
        let result3 = limiter.shouldCreateLog(type: .message, severity: .error)

        // then the logs should be allowed to be created and the counters should increase
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertTrue(result3)
        XCTAssertEqual(limiter.state.safeValue.logCounter[9], 1)
        XCTAssertEqual(limiter.state.safeValue.logCounter[13], 1)
        XCTAssertEqual(limiter.state.safeValue.logCounter[17], 1)
    }

    func test_shouldCreateLog_failure() throws {
        // given a limiter with a limit of 5 logs for each severity
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 5, warning: 5, error: 5))

        // when creating a log for each severity that would reach the limit
        limiter.state.safeValue.logCounter = [
            9: 5,
            13: 5,
            17: 5
        ]
        let result1 = limiter.shouldCreateLog(type: .message, severity: .info)
        let result2 = limiter.shouldCreateLog(type: .message, severity: .warn)
        let result3 = limiter.shouldCreateLog(type: .message, severity: .error)

        // then the logs should not be allowed to be created and the counters should not increase
        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
        XCTAssertFalse(result3)
        XCTAssertEqual(limiter.state.safeValue.logCounter[9], 5)
        XCTAssertEqual(limiter.state.safeValue.logCounter[13], 5)
        XCTAssertEqual(limiter.state.safeValue.logCounter[17], 5)
    }

    func test_shouldCreateLog_specialTypes() throws {
        // given a limiter with a limit of 5 logs for each severity
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 5, warning: 5, error: 5))

        // when creating logs of special types that would reach the limits
        limiter.state.safeValue.logCounter = [
            9: 5,
            13: 5,
            17: 5
        ]
        let result1 = limiter.shouldCreateLog(type: .internal, severity: .info)
        let result2 = limiter.shouldCreateLog(type: .hang, severity: .warn)
        let result3 = limiter.shouldCreateLog(type: .crash, severity: .error)

        // then the logs should be allowed to be created and the counters should not increase
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertTrue(result3)
        XCTAssertEqual(limiter.state.safeValue.logCounter[9], 5)
        XCTAssertEqual(limiter.state.safeValue.logCounter[13], 5)
        XCTAssertEqual(limiter.state.safeValue.logCounter[17], 5)
    }

    func test_shouldAddSpanEvent_success() throws {
        // given a limiter with a total limit of 5 custom span events
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(customSpanEventCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new event that wouldn't reach the limit
        let result = limiter.shouldAddSpanEvent(currentCount: 0)

        // then the event should be allowed to be created
        XCTAssertTrue(result)
    }

    func test_shouldAddSpanEvent_failure() throws {
        // given a limiter with a total limit of 5 custom span events
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(customSpanEventCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new event that would reach the limit
        let result = limiter.shouldAddSpanEvent(currentCount: 5)

        // then the event should not be allowed to be created
        XCTAssertFalse(result)
    }

    func test_shouldAddSpanLink_success() throws {
        // given a limiter with a total limit of 5 custom span links
        let limits = SessionLimits(links: SessionLimits.SpanLinkLimits(customSpanLinkCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new link that wouldn't reach the limit
        let result = limiter.shouldAddSpanLink(currentCount: 0)

        // then the link should be allowed to be created
        XCTAssertTrue(result)
    }

    func test_shouldAddSpanLink_failure() throws {
        // given a limiter with a total limit of 5 custom span links
        let limits = SessionLimits(links: SessionLimits.SpanLinkLimits(customSpanLinkCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new link that would reach the limit
        let result = limiter.shouldAddSpanLink(currentCount: 5)

        // then the link should not be allowed to be created
        XCTAssertFalse(result)
    }

    func test_shouldAddSpanAttribute_success() throws {
        // given a limiter with a total limit of 5 custom span attributes
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(attributeCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new attribute that wouldn't reach the limit
        let result = limiter.shouldAddSpanAttribute(currentCount: 0)

        // then the attribue should be allowed to be created
        XCTAssertTrue(result)
    }

    func test_shouldAddSpanAttribute_failure() throws {
        // given a limiter with a total limit of 5 custom span attributes
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(attributeCount: 5))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new attribute that would reach the limit
        let result = limiter.shouldAddSpanAttribute(currentCount: 5)

        // then the attribue should not be allowed to be created
        XCTAssertFalse(result)
    }
}
