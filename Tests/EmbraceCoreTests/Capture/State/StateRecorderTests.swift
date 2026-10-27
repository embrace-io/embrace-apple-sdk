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

/// Runs a hook the next time event attributes are sanitized — inside the window between the recorder's
/// decision and its write, where a part can end on another thread.
private final class InterferingSanitizer: DefaultOtelSignalsSanitizer {

    var duringNextEventSanitization: (() -> Void)?

    override func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        let hook = duringNextEventSanitization
        duringNextEventSanitization = nil
        hook?()
        return super.sanitizeSpanEventAttributes(attributes)
    }
}

/// A state value whose string does not identify it on its own: the navigation state's problem in
/// general form, without dragging the screen types into the primitive's tests.
private struct TypedValue: StateValue {
    let stateDescription: String
    let isSystemValue: Bool

    init(_ description: String, system: Bool = false) {
        self.stateDescription = description
        self.isSystemValue = system
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
        initialValue: String? = "initial",
        maxTransitions: Int = 100
    ) -> StateRecorder<String> {
        StateRecorder(
            stateName: stateName,
            initialValue: initialValue,
            otel: mockOTel,
            maxTransitions: maxTransitions
        )
    }

    /// Registers the recorder against a running part, the way the state controller does at startup.
    private func startedRecorder(
        initialValue: String = "initial",
        maxTransitions: Int = 100
    ) -> StateRecorder<String> {
        let recorder = makeRecorder(initialValue: initialValue, maxTransitions: maxTransitions)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        return recorder
    }

    private var stateSpans: [EmbraceSpan] {
        mockOTel.startedSpans.filter { $0.name == SpanSemantics.State.spanName(for: stateName) }
    }

    private func time(_ offset: TimeInterval) -> Date {
        partStart.addingTimeInterval(offset)
    }

    private func nextPartSpan() throws -> EmbraceSpan {
        try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
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
        XCTAssertNil(span.attributes[SpanSemantics.keyPrivate])
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

        // Kept current per transition so a span recovered after a crash — which never reaches
        // close — still reports a count matching its persisted events.
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "1")

        recorder.onStateChange(to: "third", at: time(2))
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")

        // Rewritten authoritatively at close, from a value read under the recorder's lock.
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

    /// The type crosses the boundary with the value it belongs to: the next part's span is seeded
    /// from the stored value, which is the one place the pair is rebuilt rather than handed in.
    func testTheCarriedOverValuesTypeSeedsTheNextPartsSpan() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Home"))

        recorder.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(1))
        recorder.onSessionPartWillEnd(at: time(60))
        recorder.onSessionPartStart(sessionSpan: try nextPartSpan(), at: time(70))

        XCTAssertEqual(stateSpans.count, 2)
        let second = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(second.attributes[SpanSemantics.State.keyInitialValue]?.description, "Backgrounded")
        XCTAssertEqual(second.attributes[SpanSemantics.State.keyValueType]?.description, "system")
    }

    /// And an untyped one carries no type over, however the part before it started.
    func testAnUntypedCarriedOverValueSeedsNoTypeOnTheNextPartsSpan() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Initializing", system: true))

        recorder.onStateChange(to: TypedValue("Home"), at: time(1))
        recorder.onSessionPartWillEnd(at: time(60))
        recorder.onSessionPartStart(sessionSpan: try nextPartSpan(), at: time(70))

        let second = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(second.attributes[SpanSemantics.State.keyInitialValue]?.description, "Home")
        XCTAssertNil(second.attributes[SpanSemantics.State.keyValueType])
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

    // MARK: - Starting value

    func testAStateWithoutAValueOpensNoSpanUntilItsFirstValue() throws {
        let recorder = makeRecorder(initialValue: nil)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        XCTAssertTrue(stateSpans.isEmpty, "a state with no value must not leave a placeholder span behind")

        recorder.onStateChange(to: "first", at: time(1))

        // The first value is the starting value, not a transition.
        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(stateSpans.count, 1)
        XCTAssertEqual(span.startTime, time(1))
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "first")
        XCTAssertTrue(span.events.isEmpty)

        recorder.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "0")
        XCTAssertNil(span.attributes[SpanSemantics.State.keyNotInSession])
        XCTAssertNil(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation])
    }

    func testAFirstValueWithNoPartRunningIsNotCountedAndSeedsTheNextPart() throws {
        let recorder = makeRecorder(initialValue: nil)

        recorder.onStateChange(to: "first", at: time(1))
        XCTAssertTrue(stateSpans.isEmpty)

        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: time(10))
        recorder.onStateChange(to: "second", at: time(11))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "first")
        let event = try XCTUnwrap(span.events.first)
        XCTAssertNil(
            event.attributes[SpanSemantics.State.keyNotInSession],
            "a starting value is not a change that happened outside a part")
    }

    func testOnceAStateHasAValueEveryLaterPartOpensASpan() throws {
        let recorder = makeRecorder(initialValue: nil)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        recorder.onStateChange(to: "first", at: time(1))
        recorder.onSessionPartWillEnd(at: time(60))

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))

        XCTAssertEqual(stateSpans.count, 2)
        XCTAssertEqual(stateSpans.last?.startTime, time(70))
        XCTAssertEqual(stateSpans.last?.attributes[SpanSemantics.State.keyInitialValue]?.description, "first")
    }

    // MARK: - Value types

    /// The primitive is generic over the value, so a typed recorder is built by hand here.
    private func startedTypedRecorder(initialValue: TypedValue) -> StateRecorder<TypedValue> {
        let recorder = StateRecorder(
            stateName: stateName,
            initialValue: initialValue,
            otel: mockOTel
        )
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        return recorder
    }

    func testTheSpanRecordsTheTypeOfItsInitialValue() throws {
        _ = startedTypedRecorder(initialValue: TypedValue("Initializing", system: true))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "Initializing")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyValueType]?.description, "system")
    }

    func testAnUntypedInitialValueWritesNoTypeAtAll() throws {
        _ = startedTypedRecorder(initialValue: TypedValue("Home"))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "Home")
        XCTAssertNil(
            span.attributes[SpanSemantics.State.keyValueType],
            "omitted, not empty — \"no type\" must stay distinguishable from a type")
    }

    /// The span attribute describes the value the part *began* with, so a later transition to a
    /// differently-typed value must not rewrite it.
    func testTransitionsDoNotRewriteTheSpansInitialValueType() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Initializing", system: true))

        recorder.onStateChange(to: TypedValue("Home"), at: time(1))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyValueType]?.description, "system")
    }

    /// The direction the test above cannot catch: an untyped value writes no key, so a span that
    /// opened untyped would keep whatever a rewrite put there.
    func testTransitionsDoNotGiveAnUntypedSpanAType() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Home"))

        recorder.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(1))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertNil(span.attributes[SpanSemantics.State.keyValueType])
    }

    func testTransitionEventsRecordTheTypeOfTheNewValue() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Home"))

        recorder.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(1))
        recorder.onStateChange(to: TypedValue("Home"), at: time(2))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.events[0].attributes[SpanSemantics.State.keyNewValue]?.description, "Backgrounded")
        XCTAssertEqual(span.events[0].attributes[SpanSemantics.State.keyValueType]?.description, "system")
        XCTAssertEqual(span.events[1].attributes[SpanSemantics.State.keyNewValue]?.description, "Home")
        XCTAssertNil(span.events[1].attributes[SpanSemantics.State.keyValueType])
    }

    /// The reason value types exist: duplicate suppression is by value, so without the type the
    /// two "Backgrounded"s below would be one value and the second change would be dropped.
    func testSameStringDifferentTypeIsADifferentValue() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Home"))

        recorder.onStateChange(to: TypedValue("Backgrounded"), at: time(1))
        recorder.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(2))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 2, "both were recorded")
        XCTAssertNil(span.events[0].attributes[SpanSemantics.State.keyValueType])
        XCTAssertEqual(span.events[1].attributes[SpanSemantics.State.keyValueType]?.description, "system")
    }

    /// Two equal typed values still dedupe — the type widens equality, it does not defeat it.
    func testSameStringSameTypeIsStillADuplicate() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Home"))

        recorder.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(1))
        recorder.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(2))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 1)
    }

    func testAValueTypeIsNotSomethingACallerCanForge() throws {
        let recorder = startedTypedRecorder(initialValue: TypedValue("Home"))

        recorder.onStateChange(
            to: TypedValue("Detail"),
            at: time(1),
            attributes: [SpanSemantics.State.keyValueType: "system"]
        )

        let span = try XCTUnwrap(stateSpans.first)
        let event = try XCTUnwrap(span.events.first)
        XCTAssertNil(
            event.attributes[SpanSemantics.State.keyValueType],
            "the key is in the reserved `emb.state.*` namespace, so a caller cannot introduce it")
    }

    // MARK: - Log stamping

    func testLogAttributeIsAbsentUntilTheStateHasAValue() {
        let recorder = makeRecorder(initialValue: nil)
        XCTAssertTrue(recorder.logAttributes.isEmpty)

        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        recorder.onStateChange(to: "first", at: time(1))

        XCTAssertEqual(recorder.logAttributes["emb.state.test-state"]?.description, "first")
    }

    func testLogAttributeTracksTheCurrentValueEvenWithoutAPart() {
        let recorder = makeRecorder()

        recorder.onStateChange(to: "offline-change", at: time(1))

        XCTAssertEqual(recorder.logAttributes["emb.state.test-state"]?.description, "offline-change")
    }

    // MARK: - Write failures

    /// The one way a write can fail: the part ends on another thread between the recorder's
    /// decision and its write. The sanitizer runs inside that window, so ending the part from it
    /// reproduces the race deterministically.
    func testAChangeWhosePartEndsMidWriteIsCountedOnTheNextPart() throws {
        let sanitizer = InterferingSanitizer()
        let recorder = StateRecorder<String>(
            stateName: stateName,
            initialValue: "initial",
            otel: mockOTel,
            sanitizer: sanitizer
        )
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        sanitizer.duringNextEventSanitization = { [weak recorder] in
            recorder?.onSessionPartWillEnd(at: self.time(10))
        }
        recorder.onStateChange(to: "a", at: time(9))

        let first = try XCTUnwrap(stateSpans.first)
        XCTAssertTrue(first.events.isEmpty, "the write lost the race, so nothing was recorded on the ended part")

        let nextPart = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "b", at: time(71))

        let next = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(next.attributes[SpanSemantics.State.keyInitialValue]?.description, "a")
        let event = try XCTUnwrap(next.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNotInSession]?.description, "1")
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
        // Passes with or without `onSessionPartDiscarded` — `onSessionPartStart` closes a stale
        // span on its own. This pins that capture resumes; what the discard call actually buys
        // is covered by `testDiscardingAPartDoesNotLinkItFromThePartSpan`.
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

        XCTAssertEqual(stateSpans.count, 1, "concurrent changes must not open two spans")
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
        // No starting value, so the part starts without a span and the first value is what opens it.
        let recorder = StateRecorder<String>(
            stateName: stateName,
            initialValue: nil,
            otel: handler,
            maxTransitions: 100
        )
        recorder.onSessionPartStart(sessionSpan: part, at: partStart)
        return (recorder, part)
    }

    private func stateSpans(in handler: InterferingOTelHandler) -> [EmbraceSpan] {
        handler.startedSpans.filter { $0.name == SpanSemantics.State.spanName(for: stateName) }
    }

    func testAChangeDuringSpanCreationDoesNotPublishASecondSpan() throws {
        let handler = InterferingOTelHandler()
        let (recorder, _) = try interferingRecorder(handler)

        // A change arrives while the span is still being created — the window in which the recorder
        // holds no lock.
        handler.duringNextCreate = { [weak recorder] in
            recorder?.onStateChange(to: "second", at: self.time(2))
        }
        recorder.onStateChange(to: "first", at: time(1))

        XCTAssertEqual(stateSpans(in: handler).count, 1, "a change mid-open must not create a span of its own")
    }

    func testAFailedOpenCountsThePartsChangesAndTheNextPartOpensNormally() throws {
        let handler = InterferingOTelHandler()
        let (recorder, _) = try interferingRecorder(handler)

        handler.failuresRemaining = 1
        recorder.onStateChange(to: "first", at: time(1))
        recorder.onStateChange(to: "second", at: time(2))
        XCTAssertTrue(stateSpans(in: handler).isEmpty, "a failed open is not retried within the part")

        recorder.onSessionPartWillEnd(at: time(60))
        let nextPart = try handler.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: time(70)
        )
        recorder.onSessionPartStart(sessionSpan: nextPart, at: time(70))
        recorder.onStateChange(to: "third", at: time(71))

        let span = try XCTUnwrap(stateSpans(in: handler).first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "second")
        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "third")
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNotInSession]?.description, "1")
    }

    // MARK: - State controller

    func testLogsAreStampedWithEveryActiveState() throws {
        let stateController = StateController()
        let screen = StateRecorder<String>(
            stateName: "screen-automatic",
            initialValue: "Initializing",
            otel: mockOTel
        )
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(screen, at: partStart)
        screen.onStateChange(to: "ProductDetailViewController", at: time(1))

        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: ["existing": "kept"]
        )
        let attributes = builder.addCurrentStates(stateController).build()

        XCTAssertEqual(attributes["existing"]?.description, "kept")
        XCTAssertEqual(
            attributes["emb.state.screen-automatic"]?.description,
            "ProductDetailViewController"
        )
        XCTAssertNil(
            attributes["emb.state.screen-automatic.value_type"],
            "a String has no type, so nothing is written beside it")
    }

    func testLogStampsCarryTheCurrentValuesType() throws {
        let stateController = StateController()
        let screen = StateRecorder<TypedValue>(
            stateName: "screen-automatic",
            initialValue: TypedValue("Initializing", system: true),
            otel: mockOTel
        )
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(screen, at: partStart)

        // Backgrounded by the SDK: typed.
        screen.onStateChange(to: TypedValue("Backgrounded", system: true), at: time(1))
        var attributes = stateController.logAttributes
        XCTAssertEqual(attributes["emb.state.screen-automatic"]?.description, "Backgrounded")
        XCTAssertEqual(attributes["emb.state.screen-automatic.value_type"]?.description, "system")

        // The same name from the app: untyped, so a log on it is not read as the SDK's.
        screen.onStateChange(to: TypedValue("Backgrounded"), at: time(2))
        attributes = stateController.logAttributes
        XCTAssertEqual(attributes["emb.state.screen-automatic"]?.description, "Backgrounded")
        XCTAssertNil(attributes["emb.state.screen-automatic.value_type"])
    }

    func testACallerCannotOverrideAStateStamp() throws {
        let stateController = StateController()
        let screen = StateRecorder<String>(
            stateName: "screen-automatic",
            initialValue: "Initializing",
            otel: mockOTel
        )
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(screen, at: partStart)
        screen.onStateChange(to: "HomeViewController", at: time(1))

        // A log emitted with a forged value for a state the SDK owns.
        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: ["emb.state.screen-automatic": "CheckoutViewController"]
        )
        let attributes = builder.addCurrentStates(stateController).build()

        XCTAssertEqual(attributes["emb.state.screen-automatic"]?.description, "HomeViewController")
    }

    func testAForgedValueTypeStampIsReplacedWhileTheStateHasOne() throws {
        let stateController = StateController()
        let screen = StateRecorder<TypedValue>(
            stateName: "screen-automatic",
            initialValue: TypedValue("Initializing", system: true),
            otel: mockOTel
        )
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(screen, at: partStart)

        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: ["emb.state.screen-automatic.value_type": "forged"]
        )
        let attributes = builder.addCurrentStates(stateController).build()

        XCTAssertEqual(attributes["emb.state.screen-automatic.value_type"]?.description, "system")
    }

    /// The untyped half of the test above, and the one with teeth: an untyped value writes no type
    /// key, so nothing overwrites a forged one and it has to be stripped. Untyped is every screen
    /// that came from the app.
    func testAForgedValueTypeStampIsStrippedWhileTheStateHasNone() throws {
        let stateController = StateController()
        let screen = StateRecorder<TypedValue>(
            stateName: "screen-automatic",
            initialValue: TypedValue("Home"),
            otel: mockOTel
        )
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(screen, at: partStart)

        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: ["emb.state.screen-automatic.value_type": "system"]
        )
        let attributes = builder.addCurrentStates(stateController).build()

        XCTAssertEqual(attributes["emb.state.screen-automatic"]?.description, "Home")
        XCTAssertNil(
            attributes["emb.state.screen-automatic.value_type"],
            "an app screen must never be readable as an SDK value")
    }

    /// The same strip for a state that has no value yet, which stamps nothing at all.
    func testAForgedStampIsStrippedForAStateWithNoValueYet() throws {
        let stateController = StateController()
        let valuelessState = StateRecorder<TypedValue>(
            stateName: "screen-automatic",
            initialValue: nil,
            otel: mockOTel
        )
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(valuelessState, at: partStart)

        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: [
                "emb.state.screen-automatic": "Checkout",
                "emb.state.screen-automatic.value_type": "system"
            ]
        )
        let attributes = builder.addCurrentStates(stateController).build()

        XCTAssertNil(attributes["emb.state.screen-automatic"])
        XCTAssertNil(attributes["emb.state.screen-automatic.value_type"])
    }

    /// The check is on the `emb.state.` prefix, so the session's own `emb.state`
    /// (foreground/background, no trailing dot) survives it.
    func testTheSessionStateAttributeIsNotStripped() throws {
        let stateController = StateController()
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(makeRecorder(), at: partStart)

        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: [CommonSemantics.keyState: "foreground"]
        )
        let attributes = builder.addCurrentStates(stateController).build()

        XCTAssertEqual(attributes[CommonSemantics.keyState]?.description, "foreground")
    }

    /// The strip runs above the state controller guard, so with nothing attached to stamp over a forged
    /// key it is the only thing that removes one.
    func testLogStampingIsANoOpWithoutAStateController() {
        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: [
                "existing": "kept",
                "emb.state.screen-automatic.value_type": "system"
            ]
        )
        let attributes = builder.addCurrentStates(nil).build()

        XCTAssertEqual(attributes["existing"]?.description, "kept")
        XCTAssertNil(attributes["emb.state.screen-automatic.value_type"])
    }

    /// A recorder registered mid-part opens its span on the part the controller already saw start,
    /// without the caller having to look the part up.
    func testRegisteringMidPartOpensTheSpanOnTheRunningPart() throws {
        let stateController = StateController()
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        stateController.register(makeRecorder(), at: time(5))

        let stateSpan = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(stateSpans.count, 1)
        XCTAssertEqual(stateSpan.startTime, time(5))

        // Bound to that part: closing the part links its span to this state span.
        stateController.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(sessionSpan.links.first?.context.spanId, stateSpan.context.spanId)
    }

    func testRegisteringAfterThePartEndedOpensNoSpan() {
        let stateController = StateController()
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.onSessionPartWillEnd(at: time(60))

        stateController.register(makeRecorder(), at: time(61))

        XCTAssertTrue(stateSpans.isEmpty)
    }

    func testRegisteringAfterThePartWasDiscardedOpensNoSpan() {
        let stateController = StateController()
        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.onSessionPartDiscarded(at: time(60))

        stateController.register(makeRecorder(), at: time(61))

        XCTAssertTrue(stateSpans.isEmpty)
    }

    func testStateControllerFansOutBoundariesAndAggregatesLogAttributes() throws {
        let stateController = StateController()
        let recorder = makeRecorder()

        stateController.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        stateController.register(recorder, at: partStart)
        XCTAssertEqual(stateSpans.count, 1)

        recorder.onStateChange(to: "second", at: time(1))
        XCTAssertEqual(
            stateController.logAttributes["emb.state.test-state"]?.description,
            "second"
        )

        stateController.onSessionPartWillEnd(at: time(60))
        XCTAssertEqual(stateSpans.first?.endTime, time(60))
    }
}
