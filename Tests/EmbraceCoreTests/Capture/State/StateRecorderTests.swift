//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// Mirrors the Android SDK's `StateFeatureTest`: these assertions are the cross-platform spec for
/// the state primitive, so a change that breaks one is a wire-contract change.
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

        // Android creates the state span with `private = false`; emitting `emb.private` here would
        // be a payload divergence.
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

    func testTransitionRecordsAnEventAndBumpsTheCount() throws {
        let recorder = startedRecorder()

        recorder.onStateChange(to: "second", at: time(1))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 1)

        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.name, "transition")
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "second")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "1")

        recorder.onStateChange(to: "third", at: time(2))
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")
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
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")

        recorder.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "2")
        // There is deliberately no `emb.state.max_enforced` key on Android; overflow is silent.
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
        XCTAssertNil(recorder.logAttribute)

        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        recorder.onStateChange(to: "second", at: time(1))

        let attribute = recorder.logAttribute
        XCTAssertEqual(attribute?.key, "emb.state.test-state")
        XCTAssertEqual(attribute?.value, "second")
    }

    func testLogAttributeTracksTheCurrentValueEvenWithoutAPart() {
        let recorder = makeRecorder()
        recorder.activate(at: partStart)

        recorder.onStateChange(to: "offline-change", at: time(1))

        XCTAssertEqual(recorder.logAttribute?.value, "offline-change")
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
