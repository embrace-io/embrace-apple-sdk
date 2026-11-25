//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
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
            $0.user.customSpanCounter = 10
            $0.user.eventCounter = 10
            $0.user.eventTypeCounter["test"] = 10
            $0.user.linkCounter = 10
            $0.user.logCounter[1] = 10
        }

        // when resetting the counters
        limiter.reset()

        // then the counters are reset
        XCTAssertEqual(limiter.state.safeValue.user.customSpanCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.user.eventCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter.count, 0)
        XCTAssertEqual(limiter.state.safeValue.user.linkCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter.count, 0)
    }

    func test_configUpdate() throws {
        // given a limiter
        let limiter = DefaultOtelSignalsLimiter()

        // when the config is updated
        let config = EditableConfig()
        config.spanEventTypeLimits = SpanEventTypeLimits(breadcrumb: 5)
        config.logSeverityLimits = LogSeverityLimits(info: 1, warn: 2, error: 3)
        NotificationCenter.default.post(name: .embraceConfigUpdated, object: config)

        // then the limits are updated
        XCTAssertEqual(limiter.state.safeValue.limits.user.events.typeLimits, config.spanEventTypeLimits)
        XCTAssertEqual(limiter.state.safeValue.limits.user.logs.severityLimits, config.logSeverityLimits)
    }

    func test_shouldCreateCustomSpan_success() throws {
        // given a limiter with a limit of custom spans
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(count: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a custom span that wouldn't reach the limit
        let result = limiter.shouldCreateCustomSpan(source: .user)

        // then the span should be allowed to be created and the counter should increase
        XCTAssertTrue(result)
        XCTAssertEqual(limiter.state.safeValue.user.customSpanCounter, 1)
    }

    func test_shouldCreateCustomSpan_failure() throws {
        // given a limiter with a limit of custom spans
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(count: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a custom span that would reach the limit
        limiter.state.safeValue.user.customSpanCounter = 5
        let result = limiter.shouldCreateCustomSpan(source: .user)

        // then the span should not be allowed to be created and the counter should not change
        XCTAssertFalse(result)
        XCTAssertEqual(limiter.state.safeValue.user.customSpanCounter, 5)
    }

    func test_shouldAddSessionEvent_success() throws {
        // given a limiter with a limit of 5 breadcrumbs
        let limiter = DefaultOtelSignalsLimiter(spanEventTypeLimits: SpanEventTypeLimits(breadcrumb: 5))

        // when creating a new breadcrumb that wouldn't reach the limit
        let result = limiter.shouldAddSessionEvent(ofType: .breadcrumb, source: .user)

        // then the event should be allowed to be created and the counter should increase
        XCTAssertTrue(result)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter["sys.breadcrumb"], 1)
    }

    func test_shouldAddSessionEvent_failure() throws {
        // given a limiter with a limit of 5 breadcrumbs
        let limiter = DefaultOtelSignalsLimiter(spanEventTypeLimits: SpanEventTypeLimits(breadcrumb: 5))

        // when creating a new breadcrumb that would reach the limit
        limiter.state.safeValue.user.eventCounter = 5
        limiter.state.safeValue.user.eventTypeCounter["sys.breadcrumb"] = 5
        let result = limiter.shouldAddSessionEvent(ofType: .breadcrumb, source: .user)

        // then the event should not be allowed to be created and the counter should not increase
        XCTAssertFalse(result)
        XCTAssertEqual(limiter.state.safeValue.user.eventCounter, 5)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter["sys.breadcrumb"], 5)
    }

    func test_shouldAddSessionEvent_emptyType() throws {
        // given a limiter
        let limiter = DefaultOtelSignalsLimiter()

        // when creating a new event with an empty type that wouldn't reach the limit
        let result = limiter.shouldAddSessionEvent(ofType: nil, source: .user)

        // then the event should be allowed to be created and the counter should increase
        XCTAssertTrue(result)
        XCTAssertEqual(limiter.state.safeValue.user.eventCounter, 1)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter["__emb.empty__"], 1)
    }

    func test_shouldAddSessionEvent_totalLimit() throws {
        // given a limiter with a total limit of 5 session span events
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(sessionSpanEventCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new event that would reach the limit
        limiter.state.safeValue.user.eventCounter = 5
        limiter.state.safeValue.user.eventTypeCounter = [
            "__emb.empty__": 2,
            "sys.breadrcumb": 2,
            "sys.push_notification": 1
        ]
        let result = limiter.shouldAddSessionEvent(ofType: nil, source: .user)

        // then the event should not be allowed to be created and the counter should not increase
        XCTAssertFalse(result)
        XCTAssertEqual(limiter.state.safeValue.user.eventCounter, 5)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter["__emb.empty__"], 2)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter["sys.breadrcumb"], 2)
        XCTAssertEqual(limiter.state.safeValue.user.eventTypeCounter["sys.push_notification"], 1)
    }

    func test_shouldCreateLog_success() throws {
        // given a limiter with a limit of 5 logs for each severity
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 5, warn: 5, error: 5))

        // when creating a log for each severity that wouldn't reach the limit
        let result1 = limiter.shouldCreateLog(type: .message, severity: .info, source: .user)
        let result2 = limiter.shouldCreateLog(type: .message, severity: .warn, source: .user)
        let result3 = limiter.shouldCreateLog(type: .message, severity: .error, source: .user)

        // then the logs should be allowed to be created and the counters should increase
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertTrue(result3)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[9], 1)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[13], 1)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[17], 1)
    }

    func test_shouldCreateLog_failure() throws {
        // given a limiter with a limit of 5 logs for each severity
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 5, warn: 5, error: 5))

        // when creating a log for each severity that would reach the limit
        limiter.state.safeValue.user.logCounter = [
            9: 5,
            13: 5,
            17: 5
        ]
        let result1 = limiter.shouldCreateLog(type: .message, severity: .info, source: .user)
        let result2 = limiter.shouldCreateLog(type: .message, severity: .warn, source: .user)
        let result3 = limiter.shouldCreateLog(type: .message, severity: .error, source: .user)

        // then the logs should not be allowed to be created and the counters should not increase
        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
        XCTAssertFalse(result3)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[9], 5)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[13], 5)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[17], 5)
    }

    func test_shouldCreateLog_specialTypes() throws {
        // given a limiter with a limit of 5 logs for each severity
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 5, warn: 5, error: 5))

        // when creating logs of special types that would reach the limits
        limiter.state.safeValue.user.logCounter = [
            9: 5,
            13: 5,
            17: 5
        ]
        let result1 = limiter.shouldCreateLog(type: .internal, severity: .info, source: .user)
        let result2 = limiter.shouldCreateLog(type: .hang, severity: .warn, source: .user)
        let result3 = limiter.shouldCreateLog(type: .crash, severity: .error, source: .user)

        // then the logs should be allowed to be created and the counters should not increase
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertTrue(result3)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[9], 5)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[13], 5)
        XCTAssertEqual(limiter.state.safeValue.user.logCounter[17], 5)
    }

    func test_shouldAddSpanEvent_success() throws {
        // given a limiter with a total limit of 5 custom span events
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(customSpanEventCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new event that wouldn't reach the limit
        let result = limiter.shouldAddSpanEvent(currentCount: 0, source: .user)

        // then the event should be allowed to be created
        XCTAssertTrue(result)
    }

    func test_shouldAddSpanEvent_failure() throws {
        // given a limiter with a total limit of 5 custom span events
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(customSpanEventCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new event that would reach the limit
        let result = limiter.shouldAddSpanEvent(currentCount: 5, source: .user)

        // then the event should not be allowed to be created
        XCTAssertFalse(result)
    }

    func test_shouldAddSpanLink_success() throws {
        // given a limiter with a total limit of 5 custom span links
        let limits = SessionLimits(user: SignalLimits(links: SignalLimits.SpanLinkLimits(customSpanLinkCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new link that wouldn't reach the limit
        let result = limiter.shouldAddSpanLink(currentCount: 0, source: .user)

        // then the link should be allowed to be created
        XCTAssertTrue(result)
    }

    func test_shouldAddSpanLink_failure() throws {
        // given a limiter with a total limit of 5 custom span links
        let limits = SessionLimits(user: SignalLimits(links: SignalLimits.SpanLinkLimits(customSpanLinkCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new link that would reach the limit
        let result = limiter.shouldAddSpanLink(currentCount: 5, source: .user)

        // then the link should not be allowed to be created
        XCTAssertFalse(result)
    }

    func test_shouldAddSpanAttribute_success() throws {
        // given a limiter with a total limit of 5 custom span attributes
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new attribute that wouldn't reach the limit
        let result = limiter.shouldAddSpanAttribute(currentCount: 0, source: .user)

        // then the attribue should be allowed to be created
        XCTAssertTrue(result)
    }

    func test_shouldAddSpanAttribute_failure() throws {
        // given a limiter with a total limit of 5 custom span attributes
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 5)))
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when creating a new attribute that would reach the limit
        let result = limiter.shouldAddSpanAttribute(currentCount: 5, source: .user)

        // then the attribue should not be allowed to be created
        XCTAssertFalse(result)
    }

    // MARK: Sources

    func test_reset_clearsAllSources() throws {
        // given a limiter with active counters for every source
        let limiter = DefaultOtelSignalsLimiter()
        limiter.state.withLock {
            $0.user.customSpanCounter = 10
            $0.captureService.customSpanCounter = 10
            $0.captureService.eventCounter = 10
            $0.captureService.logCounter[1] = 10
        }

        // when resetting the counters
        limiter.reset()

        // then the counters of every source are reset
        XCTAssertEqual(limiter.state.safeValue.user.customSpanCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.captureService.customSpanCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.captureService.eventCounter, 0)
        XCTAssertEqual(limiter.state.safeValue.captureService.logCounter.count, 0)
    }

    func test_configUpdate_onlyAffectsUserLimits() throws {
        // given a limiter
        let limiter = DefaultOtelSignalsLimiter()
        let captureServiceLimits = limiter.state.safeValue.limits.captureService

        // when the config is updated
        let config = EditableConfig()
        config.spanEventTypeLimits = SpanEventTypeLimits(breadcrumb: 5)
        config.logSeverityLimits = LogSeverityLimits(info: 1, warn: 2, error: 3)
        NotificationCenter.default.post(name: .embraceConfigUpdated, object: config)

        // then only the user limits are updated
        XCTAssertEqual(limiter.state.safeValue.limits.user.events.typeLimits, config.spanEventTypeLimits)
        XCTAssertEqual(limiter.state.safeValue.limits.captureService.events.typeLimits, captureServiceLimits.events.typeLimits)
        XCTAssertEqual(limiter.state.safeValue.limits.captureService.logs.severityLimits, captureServiceLimits.logs.severityLimits)
    }

    func test_init_remoteLimits_onlyAffectUserLimits() throws {
        // when creating a limiter with limits from the remote config
        let limiter = DefaultOtelSignalsLimiter(
            spanEventTypeLimits: SpanEventTypeLimits(breadcrumb: 5),
            logSeverityLimits: LogSeverityLimits(info: 1, warn: 2, error: 3)
        )

        // then only the user limits use them
        XCTAssertEqual(limiter.state.safeValue.limits.user.events.typeLimits, SpanEventTypeLimits(breadcrumb: 5))
        XCTAssertEqual(limiter.state.safeValue.limits.user.logs.severityLimits, LogSeverityLimits(info: 1, warn: 2, error: 3))
        XCTAssertEqual(limiter.state.safeValue.limits.captureService.events.typeLimits, SpanEventTypeLimits())
        XCTAssertEqual(limiter.state.safeValue.limits.captureService.logs.severityLimits, LogSeverityLimits())
    }

    func test_shouldCreateCustomSpan_sourcesHaveSeparateBudgets() throws {
        // given a limiter with a limit of 1 custom span for each source
        let limits = SessionLimits(
            user: SignalLimits(customSpans: SignalLimits.SpanLimits(count: 1)),
            captureService: SignalLimits(customSpans: SignalLimits.SpanLimits(count: 1))
        )
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when the user reaches its limit
        XCTAssertTrue(limiter.shouldCreateCustomSpan(source: .user))
        XCTAssertFalse(limiter.shouldCreateCustomSpan(source: .user))

        // then capture services can still create spans until they reach their own limit
        XCTAssertTrue(limiter.shouldCreateCustomSpan(source: .captureService))
        XCTAssertFalse(limiter.shouldCreateCustomSpan(source: .captureService))
        XCTAssertEqual(limiter.state.safeValue.user.customSpanCounter, 1)
        XCTAssertEqual(limiter.state.safeValue.captureService.customSpanCounter, 1)
    }

    func test_shouldAddSessionEvent_sourcesHaveSeparateBudgets() throws {
        // given a limiter with a limit of 1 session event for each source
        let limits = SessionLimits(
            user: SignalLimits(events: SignalLimits.SpanEventLimits(sessionSpanEventCount: 1)),
            captureService: SignalLimits(events: SignalLimits.SpanEventLimits(sessionSpanEventCount: 1))
        )
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // when capture services reach their limit
        XCTAssertTrue(limiter.shouldAddSessionEvent(ofType: nil, source: .captureService))
        XCTAssertFalse(limiter.shouldAddSessionEvent(ofType: nil, source: .captureService))

        // then the user can still add session events
        XCTAssertTrue(limiter.shouldAddSessionEvent(ofType: nil, source: .user))
    }

    func test_shouldCreateLog_sourcesHaveSeparateBudgets() throws {
        // given a limiter with a limit of 1 info log for users
        let limiter = DefaultOtelSignalsLimiter(logSeverityLimits: LogSeverityLimits(info: 1, warn: 1, error: 1))

        // when the user reaches its limit
        XCTAssertTrue(limiter.shouldCreateLog(type: .message, severity: .info, source: .user))
        XCTAssertFalse(limiter.shouldCreateLog(type: .message, severity: .info, source: .user))

        // then capture services can still create logs
        XCTAssertTrue(limiter.shouldCreateLog(type: .message, severity: .info, source: .captureService))
        XCTAssertEqual(limiter.state.safeValue.captureService.logCounter[9], 1)
    }

    func test_captureService_countLimits() throws {
        // given a limiter with count limits for capture services
        let limits = SessionLimits(
            captureService: SignalLimits(
                customSpans: SignalLimits.SpanLimits(attributeCount: 5),
                events: SignalLimits.SpanEventLimits(customSpanEventCount: 5),
                links: SignalLimits.SpanLinkLimits(customSpanLinkCount: 5)
            )
        )
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: limits)

        // then the limits are applied to capture services
        XCTAssertTrue(limiter.shouldAddSpanAttribute(currentCount: 4, source: .captureService))
        XCTAssertFalse(limiter.shouldAddSpanAttribute(currentCount: 5, source: .captureService))
        XCTAssertTrue(limiter.shouldAddSpanEvent(currentCount: 4, source: .captureService))
        XCTAssertFalse(limiter.shouldAddSpanEvent(currentCount: 5, source: .captureService))
        XCTAssertTrue(limiter.shouldAddSpanLink(currentCount: 4, source: .captureService))
        XCTAssertFalse(limiter.shouldAddSpanLink(currentCount: 5, source: .captureService))
    }

    func test_sdk_hasNoLimits() throws {
        // given a limiter with limits of 0 for every source
        let zero = SignalLimits(
            customSpans: SignalLimits.SpanLimits(count: 0, attributeCount: 0),
            events: SignalLimits.SpanEventLimits(sessionSpanEventCount: 0, customSpanEventCount: 0),
            links: SignalLimits.SpanLinkLimits(customSpanLinkCount: 0)
        )
        let limiter = DefaultOtelSignalsLimiter(
            sessionLimits: SessionLimits(user: zero, captureService: zero),
            logSeverityLimits: LogSeverityLimits(info: 0, warn: 0, error: 0)
        )

        // then SDK signals are always allowed
        XCTAssertTrue(limiter.shouldCreateCustomSpan(source: .sdk))
        XCTAssertTrue(limiter.shouldAddSessionEvent(ofType: nil, source: .sdk))
        XCTAssertTrue(limiter.shouldCreateLog(type: .message, severity: .info, source: .sdk))
        XCTAssertTrue(limiter.shouldAddSpanEvent(currentCount: 100, source: .sdk))
        XCTAssertTrue(limiter.shouldAddSpanLink(currentCount: 100, source: .sdk))
        XCTAssertTrue(limiter.shouldAddSpanAttribute(currentCount: 100, source: .sdk))

        // and the user is not
        XCTAssertFalse(limiter.shouldCreateCustomSpan(source: .user))
    }
}
