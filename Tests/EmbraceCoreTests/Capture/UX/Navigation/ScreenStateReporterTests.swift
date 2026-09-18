//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// Covers the wire parameters of the screen state and the seam between the broker and the state
/// primitive. The primitive's own behaviour is covered by `StateRecorderTests`.
final class ScreenStateReporterTests: XCTestCase {

    private var mockOTel: MockOTelSignalsHandler!
    private var sessionSpan: EmbraceSpan!
    private var reporter: ScreenStateReporter!

    private let partStart = Date(timeIntervalSince1970: 1_000)

    override func setUpWithError() throws {
        mockOTel = MockOTelSignalsHandler()
        sessionSpan = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: partStart
        )
        reporter = ScreenStateReporter(otel: mockOTel)
        reporter.recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        reporter.recorder.activate(at: partStart)
    }

    override func tearDownWithError() throws {
        mockOTel = nil
        sessionSpan = nil
        reporter = nil
    }

    private var stateSpan: EmbraceSpan? {
        mockOTel.startedSpans.first { $0.name == "emb-state-screen-automatic" }
    }

    private func time(_ offset: TimeInterval) -> Date {
        partStart.addingTimeInterval(offset)
    }

    // MARK: - Wire parameters

    func testStateNameAndCapAreTheContractValues() {
        XCTAssertEqual(ScreenStateReporter.stateName, "screen-automatic")
        XCTAssertEqual(ScreenStateReporter.maxTransitions, 1000)
        XCTAssertEqual(reporter.recorder.maxTransitions, 1000)
    }

    func testSpanIsOpenedEagerlySeededWithInitializing() throws {
        // Eager capture: a session in which the user never navigates still reports a screen state.
        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "Initializing")
        XCTAssertEqual(span.type.rawValue, "state")
    }

    func testSentinelsAreTheContractStrings() {
        XCTAssertEqual(Screen.initializing.stateDescription, "Initializing")
        XCTAssertEqual(Screen.backgrounded.stateDescription, "Backgrounded")
    }

    /// Only the SDK's own values are typed. A screen that came from the app is identified by its
    /// name alone, whatever that name happens to be.
    func testOnlyTheSentinelsAreSystemValues() {
        XCTAssertEqual(Screen.initializing.stateValueType, .system)
        XCTAssertEqual(Screen.backgrounded.stateValueType, .system)
        XCTAssertNil(Screen("Home").stateValueType)
        XCTAssertNil(Screen("Backgrounded").stateValueType)
    }

    func testTheSpanRecordsTheInitialValuesTypeAlongsideIt() throws {
        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyValueType]?.description, "system")
    }

    // MARK: - Recording

    func testScreenLoadRecordsATransitionAtTheObservedTime() throws {
        reporter.onScreenLoad(at: time(5), screen: Screen("Home"))

        let span = try XCTUnwrap(stateSpan)
        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.name, "transition")
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "Home")
        XCTAssertEqual(event.timestamp, time(5))
    }

    func testCurrentValueIsExposedForLogStamping() {
        reporter.onScreenLoad(at: time(1), screen: Screen("Home"))

        XCTAssertEqual(reporter.recorder.currentSerializedValue?.description, "Home")
    }

    func testEqualConsecutiveScreensAreDroppedAndCounted() throws {
        // Two distinct containers resolving to the same name pass the broker's gate but are
        // value-deduped here — this is the second half of the two-stage dedup.
        reporter.onScreenLoad(at: time(1), screen: Screen("Home"))
        reporter.onScreenLoad(at: time(2), screen: Screen("Home"))
        reporter.onScreenLoad(at: time(3), screen: Screen("Detail"))

        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")

        let detail = try XCTUnwrap(span.events.last)
        XCTAssertEqual(detail.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "1")
    }

    // MARK: - Sentinel name collisions

    /// The clash this feature exists to resolve. Duplicate suppression is by value, so without the
    /// type these two would be one value: whichever came second would be dropped, and a session
    /// that genuinely backgrounded would report that it never did.
    func testAnAppScreenNamedLikeTheSentinelIsRecordedBesideIt() throws {
        reporter.onScreenLoad(at: time(1), screen: Screen("Backgrounded"))
        reporter.onScreenLoad(at: time(2), screen: .backgrounded)

        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.events[0].attributes[SpanSemantics.State.keyNewValue]?.description, "Backgrounded")
        XCTAssertNil(
            span.events[0].attributes[SpanSemantics.State.keyValueType],
            "the app's screen carries no type")
        XCTAssertEqual(span.events[1].attributes[SpanSemantics.State.keyValueType]?.description, "system")
    }

    /// The same collision against the state's *default* value, which is already on the span as
    /// `initial_value` before any screen appears.
    func testAnAppScreenNamedLikeTheInitializingSentinelIsRecorded() throws {
        reporter.onScreenLoad(at: time(1), screen: Screen("Initializing"))

        let span = try XCTUnwrap(stateSpan)
        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "Initializing")
        XCTAssertNil(event.attributes[SpanSemantics.State.keyValueType])
    }

    // MARK: - Broker integration

    func testBrokerOutputFlowsThroughToTheSpan() throws {
        final class Container {}
        let home = Container()
        let detail = Container()

        let broker = NavigationEventBroker(onScreenLoad: reporter.onScreenLoad)

        broker.handle(.started(ObjectIdentifier(home), name: "Home", at: time(0)))
        broker.handle(.resumed(ObjectIdentifier(home), name: "Home", at: time(1)))
        broker.handle(.paused(ObjectIdentifier(home), name: "Home", at: time(2)))
        broker.handle(.started(ObjectIdentifier(detail), name: "Detail", at: time(3)))
        broker.handle(.resumed(ObjectIdentifier(detail), name: "Detail", at: time(4)))
        broker.handle(.backgrounded(at: time(10)))

        let span = try XCTUnwrap(stateSpan)
        let values = span.events.map { $0.attributes[SpanSemantics.State.keyNewValue]?.description }
        XCTAssertEqual(values, ["Home", "Detail", "Backgrounded"])

        // Load times are backdated to each container's start, not the resume.
        XCTAssertEqual(span.events[0].timestamp, time(0))
        XCTAssertEqual(span.events[1].timestamp, time(3))
        XCTAssertEqual(span.events[2].timestamp, time(10))
    }
}
