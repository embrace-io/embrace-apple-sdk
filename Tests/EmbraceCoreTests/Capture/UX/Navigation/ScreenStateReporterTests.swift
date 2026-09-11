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

    // MARK: - Recording

    func testScreenLoadRecordsATransitionAtTheObservedTime() throws {
        reporter.onScreenLoad(at: time(5), name: "Home")

        let span = try XCTUnwrap(stateSpan)
        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.name, "transition")
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "Home")
        XCTAssertEqual(event.timestamp, time(5))
    }

    func testCurrentValueIsExposedForLogStamping() {
        reporter.onScreenLoad(at: time(1), name: "Home")

        XCTAssertEqual(reporter.recorder.currentStateDescription, "Home")
    }

    func testEqualConsecutiveScreensAreDroppedAndCounted() throws {
        // Two distinct containers resolving to the same name pass the broker's gate but are
        // value-deduped here — this is the second half of the two-stage dedup.
        reporter.onScreenLoad(at: time(1), name: "Home")
        reporter.onScreenLoad(at: time(2), name: "Home")
        reporter.onScreenLoad(at: time(3), name: "Detail")

        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")

        let detail = try XCTUnwrap(span.events.last)
        XCTAssertEqual(detail.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "1")
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
