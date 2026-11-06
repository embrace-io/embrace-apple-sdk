//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

final class NetworkSpanParentControllerTests: XCTestCase {

    private var logger: MockLogger!
    private var otel: MockOTelSignalsHandler!
    private var notificationCenter: NotificationCenter!
    private var userSessionId: EmbraceIdentifier?
    private var sut: NetworkSpanParentController!

    override func setUp() {
        logger = MockLogger()
        otel = MockOTelSignalsHandler()
        notificationCenter = NotificationCenter()
        userSessionId = .random
        sut = NetworkSpanParentController(logger: logger, notificationCenter: notificationCenter) { [unowned self] in
            self.userSessionId
        }
        sut.otel = otel
    }

    // MARK: - Set and clear

    func test_set_returnsIncreasingTokens_andLastWriteWins() {
        let first = randomContext()
        let second = randomContext()

        let firstToken = sut.set(context: first)
        let secondToken = sut.set(context: second)

        XCTAssertGreaterThan(secondToken.id, firstToken.id)
        XCTAssertEqual(sut.currentContext()?.spanId, second.spanId)
    }

    func test_clear_withCurrentToken_clears() {
        let token = sut.set(context: randomContext())
        sut.clear(token: token)
        XCTAssertNil(sut.currentContext())
    }

    func test_clear_withStaleToken_doesNothing() {
        let staleToken = sut.set(context: randomContext())
        let current = randomContext()
        _ = sut.set(context: current)

        sut.clear(token: staleToken)

        XCTAssertEqual(sut.currentContext()?.spanId, current.spanId)
    }

    func test_clear_withInertToken_doesNothing() {
        let current = randomContext()
        _ = sut.set(context: current)

        sut.clear(token: .inert)

        XCTAssertEqual(sut.currentContext()?.spanId, current.spanId)
    }

    func test_set_span_usesItsContext() {
        let span = MockSpan(traceId: .randomTraceId(), name: "checkout")
        _ = sut.set(span: span)
        XCTAssertEqual(sut.currentContext()?.spanId, span.context.spanId)
        XCTAssertEqual(sut.currentContext()?.traceId, span.context.traceId)
    }

    func test_set_normalizesContext() {
        let context = randomContext()
        _ = sut.set(context: EmbraceSpanContext(spanId: context.spanId.uppercased(), traceId: context.traceId.uppercased()))
        XCTAssertEqual(sut.currentContext()?.spanId, context.spanId)
        XCTAssertEqual(sut.currentContext()?.traceId, context.traceId)
    }

    // MARK: - Rejected parents

    func test_set_invalidContext_isRejected_andLoggedOnce() {
        let current = randomContext()
        _ = sut.set(context: current)

        let first = sut.set(context: EmbraceSpanContext(spanId: "nope", traceId: "nope"))
        let second = sut.set(context: EmbraceSpanContext(spanId: "0000000000000000", traceId: current.traceId))

        XCTAssertEqual(first, .inert)
        XCTAssertEqual(second, .inert)
        XCTAssertEqual(sut.currentContext()?.spanId, current.spanId)
        XCTAssertEqual(warnings(containing: "Ignoring invalid network span parent").count, 1)
    }

    func test_set_endedSpan_isRejected_andLoggedEveryTime() {
        let current = randomContext()
        _ = sut.set(context: current)
        let ended = MockSpan(name: "ended", endTime: Date())

        XCTAssertEqual(sut.set(span: ended), .inert)
        XCTAssertEqual(sut.set(span: ended), .inert)

        XCTAssertEqual(sut.currentContext()?.spanId, current.spanId)
        XCTAssertEqual(warnings(containing: "the span has already ended").count, 2)
    }

    func test_set_spanEndingWhileBeingSet_isRejected() {
        let current = randomContext()
        _ = sut.set(context: current)
        let span = SpanEndingAfterFirstCheck(name: "checkout")
        span.onEnd = { [unowned self] in self.sut.spanDidEnd(spanId: span.context.spanId) }

        XCTAssertEqual(sut.set(span: span), .inert)

        XCTAssertEqual(sut.currentContext()?.spanId, current.spanId)
        XCTAssertEqual(warnings(containing: "the span has already ended").count, 1)
    }

    // MARK: - Automatic clearing

    func test_spanDidEnd_matchingSpan_clears() {
        let span = MockSpan(name: "checkout")
        _ = sut.set(span: span)

        sut.spanDidEnd(spanId: span.context.spanId)

        XCTAssertNil(sut.currentContext())
    }

    func test_spanDidEnd_matchingContext_clears() {
        let context = randomContext()
        _ = sut.set(context: context)

        sut.spanDidEnd(spanId: context.spanId)

        XCTAssertNil(sut.currentContext())
    }

    func test_spanDidEnd_otherSpan_doesNothing() {
        let context = randomContext()
        _ = sut.set(context: context)

        sut.spanDidEnd(spanId: .randomSpanId())

        XCTAssertEqual(sut.currentContext()?.spanId, context.spanId)
    }

    func test_userSessionDidEnd_sameUserSession_clears() throws {
        let id = try XCTUnwrap(userSessionId)
        _ = sut.set(context: randomContext())

        sut.userSessionDidEnd(id: id)

        XCTAssertNil(sut.currentContext())
    }

    func test_userSessionDidEnd_otherUserSession_doesNothing() {
        let context = randomContext()
        _ = sut.set(context: context)

        sut.userSessionDidEnd(id: .random)

        XCTAssertEqual(sut.currentContext()?.spanId, context.spanId)
    }

    func test_userSessionDidEnd_parentSetWithoutUserSession_clears() {
        userSessionId = nil
        _ = sut.set(context: randomContext())

        sut.userSessionDidEnd(id: .random)

        XCTAssertNil(sut.currentContext())
    }

    func test_userSessionDidEndNotification_clears() throws {
        let id = try XCTUnwrap(userSessionId)
        _ = sut.set(context: randomContext())

        notificationCenter.post(name: .embraceUserSessionDidEnd, object: userSession(id: id))

        XCTAssertNil(sut.currentContext())
    }

    // MARK: - Conflicts

    func test_replacingActiveSpan_logsWarningNamingBoth_andAddsEvent() throws {
        let checkout = MockSpan(name: "checkout")
        let search = MockSpan(name: "search")

        _ = sut.set(span: checkout)
        _ = sut.set(span: search)

        XCTAssertEqual(warnings(containing: "network span parent 'checkout' replaced by 'search' while still active").count, 1)

        let event = try XCTUnwrap(checkout.events.first)
        XCTAssertEqual(checkout.events.count, 1)
        XCTAssertEqual(event.name, SpanEventSemantics.NetworkSpanParent.nameReplaced)
        XCTAssertEqual(event.attributes[SpanEventSemantics.NetworkSpanParent.keyReplacedBySpanId] as? String, search.context.spanId)
        XCTAssertEqual(event.attributes[SpanEventSemantics.NetworkSpanParent.keyReplacedByName] as? String, "search")
    }

    func test_replacingActiveContext_logsSpanIds_withoutEvent() {
        let first = randomContext()
        let second = MockSpan(name: "search")

        _ = sut.set(context: first)
        _ = sut.set(span: second)

        XCTAssertEqual(warnings(containing: "network span parent span \(first.spanId) replaced by 'search'").count, 1)
        XCTAssertTrue(second.events.isEmpty)
    }

    func test_replacingActiveSpanWithContext_eventHasNoName() throws {
        let checkout = MockSpan(name: "checkout")
        let replacement = randomContext()

        _ = sut.set(span: checkout)
        _ = sut.set(context: replacement)

        let event = try XCTUnwrap(checkout.events.first)
        XCTAssertEqual(event.attributes[SpanEventSemantics.NetworkSpanParent.keyReplacedBySpanId] as? String, replacement.spanId)
        XCTAssertNil(event.attributes[SpanEventSemantics.NetworkSpanParent.keyReplacedByName])
    }

    func test_replacedSpan_getsOnlyOneEvent() {
        let checkout = MockSpan(name: "checkout")

        _ = sut.set(span: checkout)
        _ = sut.set(span: MockSpan(name: "search"))
        _ = sut.set(span: checkout)
        _ = sut.set(span: MockSpan(name: "profile"))

        XCTAssertEqual(checkout.events.count, 1)
        XCTAssertEqual(warnings(containing: "replaced by").count, 3)
    }

    func test_samePair_isReportedOncePerUserSession() throws {
        let id = try XCTUnwrap(userSessionId)
        let first = randomContext()
        let second = randomContext()

        _ = sut.set(context: first)
        _ = sut.set(context: second)
        _ = sut.set(context: first)
        _ = sut.set(context: second)
        XCTAssertEqual(warnings(containing: "replaced by").count, 2)

        sut.userSessionDidEnd(id: id)
        _ = sut.set(context: first)
        _ = sut.set(context: second)
        XCTAssertEqual(warnings(containing: "replaced by").count, 3)
    }

    func test_settingSameSpanAgain_isNotAConflict() {
        let checkout = MockSpan(name: "checkout")

        _ = sut.set(span: checkout)
        _ = sut.set(span: checkout)

        XCTAssertTrue(warnings(containing: "replaced by").isEmpty)
        XCTAssertTrue(checkout.events.isEmpty)
    }

    func test_settingAfterClearOrSpanEnd_isNotAConflict() {
        let checkout = MockSpan(name: "checkout")
        sut.clear(token: sut.set(span: checkout))

        let profile = MockSpan(name: "profile")
        _ = sut.set(span: profile)
        sut.spanDidEnd(spanId: profile.context.spanId)

        _ = sut.set(span: MockSpan(name: "settings"))

        XCTAssertTrue(warnings(containing: "replaced by").isEmpty)
        XCTAssertTrue(checkout.events.isEmpty)
        XCTAssertTrue(profile.events.isEmpty)
    }

    func test_conflictsOverTheLimit_areCounted_andReportedAtUserSessionEnd() throws {
        let id = try XCTUnwrap(userSessionId)
        let limit = NetworkSpanParentController.maxReportedConflictsPerUserSession
        let extra = 3

        _ = sut.set(context: randomContext())
        for _ in 0..<(limit + extra) {
            _ = sut.set(context: randomContext())
        }

        XCTAssertEqual(warnings(containing: "replaced by").count, limit)
        XCTAssertTrue(otel.logs.isEmpty)

        sut.userSessionDidEnd(id: id)

        let log = try XCTUnwrap(otel.logs.first)
        XCTAssertEqual(otel.logs.count, 1)
        XCTAssertEqual(log.attributes["emb.network_span_parent.unreported_conflicts"] as? String, String(extra))

        // the limit starts over with the next user session
        _ = sut.set(context: randomContext())
        _ = sut.set(context: randomContext())
        XCTAssertEqual(warnings(containing: "replaced by").count, limit + 1)
    }

    func test_userSessionDidEnd_withoutDroppedConflicts_sendsNoLog() throws {
        let id = try XCTUnwrap(userSessionId)
        _ = sut.set(context: randomContext())
        _ = sut.set(context: randomContext())

        sut.userSessionDidEnd(id: id)

        XCTAssertTrue(otel.logs.isEmpty)
    }

    // MARK: - Thread safety

    func test_concurrentAccess_staleTokensNeverClearALaterParent() {
        let iterations = 1000

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            let context = randomContext()
            let token = sut.set(context: context)
            _ = sut.currentContext()
            if index % 3 == 0 {
                sut.spanDidEnd(spanId: context.spanId)
            }
            sut.clear(token: token)
        }

        // every set was followed by a clear of its own token or an end of its own span,
        // so the last parent set is always cleared
        XCTAssertNil(sut.currentContext())

        let survivor = randomContext()
        let survivorToken = sut.set(context: survivor)
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            sut.clear(token: EmbraceNetworkSpanParentToken(id: survivorToken.id - 1))
            _ = sut.currentContext()
        }
        XCTAssertEqual(sut.currentContext()?.spanId, survivor.spanId)
    }
}

/// Span that hasn't ended the first time its end time is read, and ends right after, as if it
/// ended on another thread between two reads.
private final class SpanEndingAfterFirstCheck: EmbraceSpan {
    private let span: MockSpan
    private var didCheckEndTime = false
    var onEnd: (() -> Void)?

    init(name: String) {
        span = MockSpan(name: name)
    }

    var endTime: Date? {
        guard didCheckEndTime else {
            didCheckEndTime = true
            span.endTime = Date()
            onEnd?()
            return nil
        }
        return span.endTime
    }

    var name: String { span.name }
    var context: EmbraceSpanContext { span.context }
    var parentSpanId: String? { span.parentSpanId }
    var type: EmbraceType { span.type }
    var status: EmbraceSpanStatus { span.status }
    var startTime: Date { span.startTime }
    var events: [EmbraceSpanEvent] { span.events }
    var links: [EmbraceSpanLink] { span.links }
    var attributes: EmbraceAttributes { span.attributes }
    var sessionId: EmbraceIdentifier? { span.sessionId }
    var processId: EmbraceIdentifier { span.processId }

    func setStatus(_ status: EmbraceSpanStatus) { span.setStatus(status) }

    func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: EmbraceAttributes) -> EmbraceSpanEvent? {
        span.addEvent(name: name, type: type, timestamp: timestamp, attributes: attributes)
    }

    func addLink(spanId: String, traceId: String, attributes: EmbraceAttributes) -> EmbraceSpanLink? {
        span.addLink(spanId: spanId, traceId: traceId, attributes: attributes)
    }

    func setAttribute(key: String, value: EmbraceAttributeValue?) { span.setAttribute(key: key, value: value) }
    func end(endTime: Date) { span.end(endTime: endTime) }
    func end() { span.end() }
}

extension NetworkSpanParentControllerTests {
    fileprivate func randomContext() -> EmbraceSpanContext {
        return EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())
    }

    fileprivate func warnings(containing text: String) -> [String] {
        return logger.loggedMessages.filter { $0.level == .warning && $0.message.contains(text) }.map(\.message)
    }

    fileprivate func userSession(id: EmbraceIdentifier) -> EmbraceUserSession {
        return ImmutableUserSession(
            id: id,
            startTime: Date(),
            maxDuration: 3600,
            inactivityTimeout: 600,
            partIndex: 1,
            endTime: Date(),
            isBackgroundOnly: false
        )
    }
}
