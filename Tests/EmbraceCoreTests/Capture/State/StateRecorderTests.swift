//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// A handler that can interfere *during* span creation.
///
/// Span creation is the one window where the recorder is holding no lock, so it is where the
/// interesting races live. Re-entering from here reproduces them deterministically instead of
/// hoping a threaded test lands on the right interleaving.
private final class InterferingOTelHandler: MockOTelSignalsHandler {

    /// Runs once, inside the next `createInternalSpan`, before the span is returned.
    var duringNextCreate: (() -> Void)?

    /// When > 0, the next create throws instead of returning a span.
    var failuresRemaining = 0

    struct CreateFailure: Error {}

    override func _createSpan(
        name: String,
        parentSpan: EmbraceSpan? = nil,
        type: EmbraceType,
        status: EmbraceSpanStatus = .unset,
        startTime: Date,
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: EmbraceAttributes = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
        isInternal: Bool = true
    ) throws -> EmbraceSpan {

        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw CreateFailure()
        }

        let hook = duringNextCreate
        duringNextCreate = nil
        hook?()

        return try super._createSpan(
            name: name,
            parentSpan: parentSpan,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            autoTerminationCode: autoTerminationCode,
            isInternal: isInternal
        )
    }
}

/// These assertions are the specification for the state primitive: they pin the payload the backend
/// reads, so a change that breaks one is a wire-contract change and needs to be deliberate.
final class StateRecorderTests: XCTestCase {

    private var mockOTel: MockOTelSignalsHandler!
    private var sessionSpan: EmbraceSpan!

    private let stateName = "test-state"
    private let partStart = Date(timeIntervalSince1970: 1_000)

    override func setUpWithError() throws {
        mockOTel = MockOTelSignalsHandler()
        sessionSpan = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: partStart
        )
    }

    override func tearDownWithError() throws {
        mockOTel = nil
        sessionSpan = nil
    }

    // MARK: - Helpers

    private func makeRecorder(
        defaultValue: String = "initial",
        maxTransitions: Int = 100,
        capturesOnCreation: Bool = true
    ) -> StateRecorder<String> {
        StateRecorder(
            stateName: stateName,
            defaultValue: defaultValue,
            otel: mockOTel,
            maxTransitions: maxTransitions,
            capturesOnCreation: capturesOnCreation
        )
    }

    /// Registers the recorder against a running part, the way the coordinator does at startup.
    private func startedRecorder(
        defaultValue: String = "initial",
        maxTransitions: Int = 100
    ) -> StateRecorder<String> {
        let recorder = makeRecorder(defaultValue: defaultValue, maxTransitions: maxTransitions)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        recorder.activate(at: partStart)
        return recorder
    }

    private var stateSpans: [EmbraceSpan] {
        mockOTel.startedSpans.filter { $0.name == SpanSemantics.State.spanName(for: stateName) }
    }

    private func time(_ offset: TimeInterval) -> Date {
        partStart.addingTimeInterval(offset)
    }

    // MARK: - Span shape

    func testOpensOneSpanPerPartSeededWithTheCurrentValue() throws {
        _ = startedRecorder()

        XCTAssertEqual(stateSpans.count, 1)
        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.name, "emb-state-test-state")
        XCTAssertEqual(span.type.rawValue, "state")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "initial")
        XCTAssertEqual(span.startTime, partStart)
        XCTAssertNil(span.endTime)
    }

    func testStateSpanIsNotPrivate() throws {
        _ = startedRecorder()

        // The state span is deliberately not private; emitting `emb.private` here would change the
        // payload the backend sees.
        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertNil(span.attributes[SpanSemantics.keyIsPrivateSpan])
    }

    func testSpanClosesAtPartEndWithThePartEndTime() throws {
        let recorder = startedRecorder()
        let partEnd = time(60)

        recorder.onSessionPartWillEnd(at: partEnd)

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.endTime, partEnd)
    }

    func testPartSpanIsLinkedToTheStateSpanOnClose() throws {
        let recorder = startedRecorder()
        let stateSpan = try XCTUnwrap(stateSpans.first)

        recorder.onSessionPartWillEnd(at: time(60))

        let link = try XCTUnwrap(sessionSpan.links.first)
        XCTAssertEqual(link.context.spanId, stateSpan.context.spanId)
        XCTAssertEqual(link.context.traceId, stateSpan.context.traceId)
        XCTAssertEqual(link.attributes[SpanSemantics.keyLinkType]?.description, "STATE")
    }

    // MARK: - Transitions

    func testTransitionRecordsAnEventAndTheCountIsWrittenAtClose() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 1)

        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.name, "transition")
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "second")

        recorder.onStateChange(to: "third", at: time(2))
        XCTAssertEqual(span.events.count, 2)

        // The count is authored once, at close, from a value read under the recorder's lock — not
        // re-written per transition, which is what the contract specifies.
        XCTAssertNil(span.attributes[SpanSemantics.State.keyTransitionCount])
        recorder.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")
    }

    func testAPartWithNoTransitionsStillReportsACountOfZero() throws {
        let recorder = startedRecorder()

        recorder.onSessionPartWillEnd(at: time(60))

        // `emb.state.transition_count` is a required span attribute, so a changeless part must
        // report zero rather than omit it — otherwise "no changes" is indistinguishable from
        // "this SDK doesn't report the count".
        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertTrue(span.events.isEmpty)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "0")
    }

    func testEventUsesTheObservedTimeNotTheProcessingTime() throws {
        let recorder = startedRecorder()
        let observed = time(5)

        recorder.onStateChange(to: "second", at: observed)

        let event = try XCTUnwrap(stateSpans.first?.events.first)
        XCTAssertEqual(event.timestamp, observed)
    }

    func testCallerAttributesAreRecordedButCannotOverrideBuiltInKeys() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(
            to: "second",
            at: time(1),
            attributes: [
                "custom": "kept",
                SpanSemantics.State.keyNewValue: "forged",
                SpanSemantics.State.keyNotInSession: "forged"
            ]
        )

        let event = try XCTUnwrap(stateSpans.first?.events.first)
        XCTAssertEqual(event.attributes["custom"]?.description, "kept")
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "second")
        // No unrecorded transitions happened, so the forged counter must not survive either.
        XCTAssertNil(event.attributes[SpanSemantics.State.keyNotInSession])
    }

    // MARK: - Accounting

    func testDuplicateValueIsSuppressedAndCountedAsDropped() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1))
        recorder.onStateChange(to: "second", at: time(2))
        recorder.onStateChange(to: "second", at: time(3))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 1, "Equal consecutive values must not produce events")

        // The two dropped duplicates surface on the next recorded transition.
        recorder.onStateChange(to: "third", at: time(4))
        let event = try XCTUnwrap(span.events.last)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "2")
    }

    func testCapOverflowIsCountedAsDroppedRatherThanRecorded() throws {
        let recorder = startedRecorder(maxTransitions: 2)

        recorder.onStateChange(to: "a", at: time(1))
        recorder.onStateChange(to: "b", at: time(2))
        recorder.onStateChange(to: "c", at: time(3))
        recorder.onStateChange(to: "d", at: time(4))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 2, "Recorded transitions must stop at the cap")

        recorder.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "2")
        // There is deliberately no `emb.state.max_enforced` key; overflow is counted, not announced.
        XCTAssertNil(span.attributes["emb.state.max_enforced"])
    }

    func testChangesOutsideASessionPartAreCountedAsNotInSession() throws {
        let recorder = makeRecorder()
        recorder.activate(at: partStart)

        // No part is running, so nothing can be recorded.
        recorder.onStateChange(to: "a", at: time(1))
        recorder.onStateChange(to: "b", at: time(2))
        XCTAssertTrue(stateSpans.isEmpty)

        // The counts flush onto the first transition recorded in the next part.
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: time(10))
        recorder.onStateChange(to: "c", at: time(11))

        let event = try XCTUnwrap(stateSpans.first?.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNotInSession]?.description, "2")
    }

    func testCoalescedChangesDeclaredByTheCallerAreCounted() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1), coalescing: 4)

        // The coalesced count is added before the flush, so it rides on the very event it
        // accompanies rather than waiting for the next one.
        let event = try XCTUnwrap(stateSpans.first?.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "4")

        recorder.onSessionPartWillEnd(at: time(60))
        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertNil(
            span.attributes[SpanSemantics.State.keyDroppedByInstrumentation],
            "The count was already flushed onto the event; it must not be double-counted at close")
    }

    func testResidualCountsLandOnTheSpanAtCloseWhenNoFurtherEventComes() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1))
        recorder.onStateChange(to: "second", at: time(2))  // dropped duplicate

        recorder.onSessionPartWillEnd(at: time(60))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "1")
    }

    func testZeroedCountersAreOmittedEntirely() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1))
        recorder.onSessionPartWillEnd(at: time(60))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertNil(span.attributes[SpanSemantics.State.keyNotInSession])
        XCTAssertNil(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation])
        XCTAssertNil(span.events.first?.attributes[SpanSemantics.State.keyNotInSession])
    }

    // MARK: - Carry-over

    func testValueCarriesOverToTheNextPart() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1))
        recorder.onSessionPartWillEnd(at: time(60))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))

        XCTAssertEqual(stateSpans.count, 2)
        let second = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(second.attributes[SpanSemantics.State.keyInitialValue]?.description, "second")
    }

    func testValueIsRetainedEvenWhenTheChangeWasNeverRecorded() throws {
        // The value-retention invariant: a change dropped by the cap must still seed the next part.
        let recorder = startedRecorder(maxTransitions: 1)

        recorder.onStateChange(to: "recorded", at: time(1))
        recorder.onStateChange(to: "dropped-by-cap", at: time(2))
        recorder.onSessionPartWillEnd(at: time(60))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))

        let second = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(second.attributes[SpanSemantics.State.keyInitialValue]?.description, "dropped-by-cap")
        XCTAssertEqual(recorder.currentValue, "dropped-by-cap")
    }

    func testPerPartTransitionBudgetResetsWithEachPart() throws {
        let recorder = startedRecorder(maxTransitions: 1)

        recorder.onStateChange(to: "a", at: time(1))
        recorder.onStateChange(to: "b", at: time(2))  // over cap
        recorder.onSessionPartWillEnd(at: time(60))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "c", at: time(71))

        XCTAssertEqual(stateSpans.last?.events.count, 1, "The cap is per part, not per process")
    }

    // MARK: - Eager vs lazy

    func testLazyStateOpensNoSpanUntilItsFirstChange() throws {
        let recorder = makeRecorder(capturesOnCreation: false)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        XCTAssertTrue(stateSpans.isEmpty, "A lazy state must not leave a default-value span behind")

        recorder.onStateChange(to: "second", at: time(1))

        XCTAssertEqual(stateSpans.count, 1)
        let span = try XCTUnwrap(stateSpans.first)
        // The span opens seeded with the value *before* the change, then records the transition.
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "initial")
        XCTAssertEqual(span.events.count, 1)
    }

    // MARK: - Log stamping

    func testLogAttributeIsAbsentUntilTheStateIsActive() {
        let recorder = makeRecorder(capturesOnCreation: false)
        XCTAssertNil(recorder.currentStateDescription)

        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        recorder.onStateChange(to: "second", at: time(1))

        XCTAssertEqual(recorder.currentStateDescription, "second")
    }

    func testLogAttributeTracksTheCurrentValueEvenWithoutAPart() {
        let recorder = makeRecorder()
        recorder.activate(at: partStart)

        recorder.onStateChange(to: "offline-change", at: time(1))

        XCTAssertEqual(recorder.currentStateDescription, "offline-change")
    }

    // MARK: - Write failures (the paths the defensive code exists for)

    func testCountsSurviveAPartCloseWhoseSpanAlreadyEnded() throws {
        // Regression: `closeSpan` used to zero the counters before handing them to `end`, which
        // dropped them when the span had already been closed — losing them permanently.
        let recorder = startedRecorder()
        let span = try XCTUnwrap(stateSpans.first)

        recorder.onStateChange(to: "a", at: time(1))
        recorder.onStateChange(to: "a", at: time(2))  // duplicate → dropped, counted

        // Something else ends the span underneath the recorder.
        span.end(endTime: time(30))

        recorder.onSessionPartWillEnd(at: time(60))

        // The residual count could not be written to the dead span, so it must have been retained
        // and must land on the next part instead of vanishing.
        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "b", at: time(71))

        let event = try XCTUnwrap(stateSpans.last?.events.first)
        XCTAssertEqual(
            event.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description,
            "1",
            "counts must survive a close whose span had already ended")
    }

    func testTransitionOntoAnEndedSpanIsRecycledAsNotInSession() throws {
        let recorder = startedRecorder()
        let span = try XCTUnwrap(stateSpans.first)

        span.end(endTime: time(10))

        // The write fails, so the change is recycled onto the next part rather than lost.
        recorder.onStateChange(to: "a", at: time(11))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartWillEnd(at: time(60))
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "b", at: time(71))

        let event = try XCTUnwrap(stateSpans.last?.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNotInSession]?.description, "1")
    }

    func testTheBudgetSlotIsReturnedWhenAWriteFails() throws {
        // A failed write must not consume the per-part transition budget.
        let recorder = startedRecorder(maxTransitions: 1)
        let span = try XCTUnwrap(stateSpans.first)
        span.end(endTime: time(5))

        recorder.onStateChange(to: "a", at: time(6))  // fails, must not spend the only slot

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartWillEnd(at: time(60))
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "b", at: time(71))

        XCTAssertEqual(stateSpans.last?.events.count, 1)
    }

    // MARK: - Discarded parts

    func testDiscardingAPartRetainsTheCountersForTheNextPart() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "a", at: time(1))
        recorder.onStateChange(to: "a", at: time(2))  // dropped duplicate

        // The part is thrown away — its span cannot carry the counts.
        recorder.onSessionPartDiscarded(at: time(60))
        XCTAssertEqual(stateSpans.first?.endTime, time(60))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "b", at: time(71))

        let event = try XCTUnwrap(stateSpans.last?.events.first)
        XCTAssertEqual(
            event.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description,
            "1",
            "counts from a discarded part must carry over rather than being flushed onto it")
    }

    func testDiscardingAPartDoesNotLinkItFromThePartSpan() throws {
        let recorder = startedRecorder()

        recorder.onSessionPartDiscarded(at: time(60))

        XCTAssertTrue(
            sessionSpan.links.isEmpty,
            "a discarded part must not gain a STATE link to a span that is going away")
    }

    func testANewPartAfterADiscardOpensItsOwnSpan() throws {
        // The bug the discard path exists to prevent: a stale token blocking the next part.
        let recorder = startedRecorder()
        recorder.onSessionPartDiscarded(at: time(60))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))

        XCTAssertEqual(stateSpans.count, 2, "the next part must open its own state span")
        XCTAssertNil(stateSpans.last?.endTime)
    }

    // MARK: - Lifecycle robustness

    func testAPartStartForAnAlreadyEndedSpanIsIgnored() throws {
        let recorder = makeRecorder()
        let deadPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: partStart
        )
        deadPart.end(endTime: time(5))

        recorder.onSessionPartStart(sessionSpan: deadPart, at: time(6))
        recorder.activate(at: time(6))

        XCTAssertTrue(
            stateSpans.isEmpty,
            "binding to a dead part would open a span that outlives it and links from the wrong part")
    }

    func testASecondPartStartClosesTheSpanLeftOpenByTheFirst() throws {
        let recorder = startedRecorder()
        let firstSpan = try XCTUnwrap(stateSpans.first)

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))

        XCTAssertEqual(firstSpan.endTime, time(70), "the orphaned span must be closed, not left open")
        XCTAssertEqual(stateSpans.count, 2)
        XCTAssertNil(stateSpans.last?.endTime)
    }

    // MARK: - Concurrency

    func testConcurrentChangesNeitherLoseCountsNorOpenTwoSpans() throws {
        let threads = 8
        let perThread = 250
        let recorder = startedRecorder(maxTransitions: threads * perThread)

        DispatchQueue.concurrentPerform(iterations: threads) { thread in
            for i in 0..<perThread {
                recorder.onStateChange(to: "value-\(thread)-\(i)", at: self.time(Double(i)))
            }
        }

        XCTAssertEqual(stateSpans.count, 1, "concurrent activation must not open two spans")
        let span = try XCTUnwrap(stateSpans.first)
        recorder.onSessionPartWillEnd(at: time(9_999))

        // Every change is either an event or counted somewhere — nothing vanishes.
        func counted(_ key: String) -> Int {
            let onSpan = Int(span.attributes[key]?.description ?? "") ?? 0
            let onEvents = span.events.compactMap { Int($0.attributes[key]?.description ?? "") }.reduce(0, +)
            return onSpan + onEvents
        }

        let events = span.events.filter { $0.name == SpanSemantics.State.transitionEventName }.count
        let accounted =
            events
            + counted(SpanSemantics.State.keyDroppedByInstrumentation)
            + counted(SpanSemantics.State.keyNotInSession)

        XCTAssertEqual(accounted, threads * perThread)

        // Sound because the count is written once at close from a value read under the lock. While
        // it was re-written per transition this held only by scheduling luck: two racers could take
        // counts N and N+1 and land them in either order, leaving the lower value on the span.
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, String(events))
    }

    // MARK: - Concurrent open

    /// Helper: a recorder wired to a handler that can interfere during span creation.
    private func interferingRecorder(
        _ handler: InterferingOTelHandler
    ) throws -> (StateRecorder<String>, EmbraceSpan) {
        let part = try handler.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: partStart
        )
        let recorder = StateRecorder<String>(
            stateName: stateName,
            defaultValue: "initial",
            otel: handler,
            maxTransitions: 100,
            capturesOnCreation: true
        )
        recorder.onSessionPartStart(sessionSpan: part, at: partStart)
        return (recorder, part)
    }

    private func stateSpans(in handler: InterferingOTelHandler) -> [EmbraceSpan] {
        handler.startedSpans.filter { $0.name == SpanSemantics.State.spanName(for: stateName) }
    }

    func testASecondOpenDuringSpanCreationDoesNotPublishAGhostSpan() throws {
        let handler = InterferingOTelHandler()
        let (recorder, _) = try interferingRecorder(handler)

        // A change arrives while the first span is still being created — the window in which the
        // recorder holds no lock. Both callers previously saw `.part` and both created a span;
        // the loser was ended, but creation had already persisted it, so it still shipped.
        handler.duringNextCreate = { [weak recorder] in
            recorder?.onStateChange(to: "second", at: self.time(1))
        }
        recorder.activate(at: partStart)

        XCTAssertEqual(stateSpans(in: handler).count, 1, "a losing racer must not create a span at all")
    }

    func testAFailedOpenLeavesTheRecorderAbleToRetry() throws {
        let handler = InterferingOTelHandler()
        let (recorder, _) = try interferingRecorder(handler)

        handler.failuresRemaining = 1
        recorder.activate(at: partStart)
        XCTAssertTrue(stateSpans(in: handler).isEmpty)

        // The failed attempt must hand the part back. If it left the recorder mid-open, this
        // change — and every later one in this part — would silently never open a span.
        recorder.onStateChange(to: "second", at: time(1))

        // Fully recovered: the span opened (seeded with the value at open time, not the new one)
        // and the change that triggered the retry was recorded on it.
        let span = try XCTUnwrap(stateSpans(in: handler).first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "initial")

        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "second")
    }

    // MARK: - Coordinator

    func testLogsAreStampedWithEveryActiveState() throws {
        let coordinator = StateCaptureCoordinator()
        let screen = StateRecorder<String>(
            stateName: "screen-automatic",
            defaultValue: "Initializing",
            otel: mockOTel
        )
        coordinator.register(screen, sessionSpan: sessionSpan, at: partStart)
        screen.onStateChange(to: "ProductDetailViewController", at: time(1))

        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: ["existing": "kept"]
        )
        let attributes = builder.addCurrentStates(coordinator).build()

        XCTAssertEqual(attributes["existing"]?.description, "kept")
        XCTAssertEqual(
            attributes["emb.state.screen-automatic"]?.description,
            "ProductDetailViewController"
        )
    }

    func testLogStampingIsANoOpWithoutACoordinator() {
        let builder = EmbraceLogAttributesBuilder(session: nil, initialAttributes: [:])
        XCTAssertTrue(builder.addCurrentStates(nil).build().isEmpty)
    }

    func testCoordinatorFansOutBoundariesAndAggregatesLogAttributes() throws {
        let coordinator = StateCaptureCoordinator()
        let recorder = makeRecorder()

        coordinator.register(recorder, sessionSpan: sessionSpan, at: partStart)
        XCTAssertEqual(stateSpans.count, 1)

        recorder.onStateChange(to: "second", at: time(1))
        XCTAssertEqual(
            coordinator.logAttributes["emb.state.test-state"]?.description,
            "second"
        )

        coordinator.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(stateSpans.first?.endTime, time(60))
    }
}
