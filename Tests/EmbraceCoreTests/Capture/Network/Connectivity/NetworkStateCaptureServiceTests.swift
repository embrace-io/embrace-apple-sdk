//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// A monitor the tests feed by hand. Mirrors the single-use contract of `NWPathMonitor`: once
/// cancelled it refuses further updates, so a test sending after cancel is exercising the
/// service's own guard, not the mock's.
private final class MockPathMonitor: NetworkPathMonitoring {
    var onPathUpdate: ((NetworkPathSnapshot, Date) -> Void)?
    private(set) var started = false
    private(set) var cancelled = false

    func start() { started = true }
    func cancel() { cancelled = true }

    func send(satisfied: Bool = true, wifi: Bool = false, cellular: Bool = false, at time: Date) {
        onPathUpdate?(
            NetworkPathSnapshot(isSatisfied: satisfied, usesWiFi: wifi, usesCellular: cellular),
            time
        )
    }
}

final class NetworkStateCaptureServiceTests: XCTestCase {

    private var mockOTel: MockOTelSignalsHandler!
    private var sessionSpan: EmbraceSpan!
    private var service: NetworkStateCaptureService!
    private var monitors: [MockPathMonitor]!

    private let partStart = Date(timeIntervalSince1970: 1_000)

    override func setUpWithError() throws {
        mockOTel = MockOTelSignalsHandler()
        sessionSpan = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: partStart
        )
        monitors = []
        service = NetworkStateCaptureService(createMonitor: { [weak self] in
            let monitor = MockPathMonitor()
            self?.monitors.append(monitor)
            return monitor
        })
    }

    override func tearDownWithError() throws {
        service = nil
        monitors = nil
        sessionSpan = nil
        mockOTel = nil
    }

    // MARK: - Helpers

    private var monitor: MockPathMonitor! { monitors.last }

    private func startedService() {
        service.install(otel: mockOTel)
        service.start()
    }

    private var stateSpans: [EmbraceSpan] {
        mockOTel.startedSpans.filter { $0.name == "emb-state-network" }
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

    // MARK: - Lifecycle

    func testStartBuildsTheRecorderAndStartsAMonitor() {
        startedService()

        XCTAssertNotNil(service.recorder)
        XCTAssertEqual(monitors.count, 1)
        XCTAssertTrue(monitor.started)
    }

    func testStopCancelsTheMonitor() {
        startedService()

        service.stop()

        XCTAssertTrue(monitor.cancelled)
    }

    func testRestartKeepsTheRecorderAndCreatesAFreshMonitor() {
        startedService()
        let firstRecorder = service.recorder
        let firstMonitor = monitor

        service.stop()
        service.start()

        // One recorder forever (a second would mean two spans per part); monitors are single-use.
        XCTAssertTrue(service.recorder === firstRecorder)
        XCTAssertEqual(monitors.count, 2)
        XCTAssertFalse(firstMonitor === monitor)
        XCTAssertTrue(monitor.started)
    }

    func testAnUpdateDeliveredAfterStopIsNotRecorded() throws {
        startedService()
        service.recorder?.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))
        service.stop()

        // A cancelled NWPathMonitor can still have a queued update in flight.
        monitor.send(satisfied: false, at: time(2))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 0)
        XCTAssertEqual(service.recorder?.currentValue, .wifi)
    }

    func testStopAndRestartStillYieldsOneSpanPerPart() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))

        service.stop()
        service.start()
        recorder.onSessionPartWillEnd(at: time(60))
        recorder.onSessionPartStart(sessionSpan: try nextPartSpan(), at: time(70))

        XCTAssertEqual(stateSpans.count, 2)
    }

    // MARK: - Span shape (NS-1)

    func testTheSpanCarriesTheSharedContractNameAndType() throws {
        startedService()
        service.recorder?.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        monitor.send(wifi: true, at: time(1))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.name, "emb-state-network")
        XCTAssertEqual(span.type.rawValue, "state")
    }

    func testTheSpanIsLinkedFromThePartSpanAtClose() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))
        let stateSpan = try XCTUnwrap(stateSpans.first)

        recorder.onSessionPartWillEnd(at: time(60))

        let link = try XCTUnwrap(sessionSpan.links.first)
        XCTAssertEqual(link.context.spanId, stateSpan.context.spanId)
        XCTAssertEqual(link.attributes[SpanSemantics.keyLinkType]?.description, "STATE")
    }

    // MARK: - First value (NS-5)

    func testTheFirstPathIsTheInitialValueNotATransition() throws {
        startedService()
        service.recorder?.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        monitor.send(wifi: true, at: time(1))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "wifi")
        XCTAssertEqual(span.events.count, 0)
    }

    func testAPathObservedBeforeThePartSeedsThePartsSpan() throws {
        startedService()
        monitor.send(cellular: true, at: time(-5))

        service.recorder?.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "wan")
        XCTAssertEqual(span.events.count, 0)
    }

    // MARK: - Transitions (NS-6, NS-7, NS-9)

    func testAChangeRecordsOneTransitionWithTheObservationTime() throws {
        startedService()
        service.recorder?.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))

        let observed = time(10)
        monitor.send(satisfied: false, at: observed)

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 1)
        let event = try XCTUnwrap(span.events.first)
        XCTAssertEqual(event.name, SpanSemantics.State.transitionEventName)
        XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "none")
        XCTAssertEqual(event.timestamp, observed)
    }

    func testRepeatedReadingsOfTheSameValueAddNoEventAndAreCounted() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))

        // NWPathMonitor re-reports on attribute changes that do not change our mapping.
        monitor.send(wifi: true, at: time(2))
        monitor.send(wifi: true, cellular: true, at: time(3))

        recorder.onSessionPartWillEnd(at: time(60))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 0)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "2")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "0")
    }

    func testTransitionCountMatchesTheEventCountAtClose() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))
        monitor.send(cellular: true, at: time(2))
        monitor.send(satisfied: false, at: time(3))

        recorder.onSessionPartWillEnd(at: time(60))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 2)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "2")
    }

    // MARK: - Cap (NS-8)

    func testAtMostOneHundredTransitionsAreRecordedPerPart() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(0))

        // 101 real changes: alternate so every send is a change.
        for i in 1...101 {
            monitor.send(satisfied: i % 2 == 0, wifi: i % 2 == 0, at: time(Double(i)))
        }

        recorder.onSessionPartWillEnd(at: time(200))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.events.count, 100)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyTransitionCount]?.description, "100")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "1")
    }

    func testTheNextPartStartsWithTheValueCurrentAfterAnOverflow() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(0))
        for i in 1...101 {
            monitor.send(satisfied: i % 2 == 0, wifi: i % 2 == 0, at: time(Double(i)))
        }

        recorder.onSessionPartWillEnd(at: time(200))
        recorder.onSessionPartStart(sessionSpan: try nextPartSpan(), at: time(201))

        // 101 iterations end on i = 101, an odd index: not satisfied.
        let span = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "none")
    }

    // MARK: - Part carry-over (NS-10)

    func testEachNewPartOpensSeededWithTheCurrentValue() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))
        monitor.send(cellular: true, at: time(2))

        recorder.onSessionPartWillEnd(at: time(60))
        recorder.onSessionPartStart(sessionSpan: try nextPartSpan(), at: time(70))

        XCTAssertEqual(stateSpans.count, 2)
        let span = try XCTUnwrap(stateSpans.last)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "wan")
        XCTAssertEqual(span.events.count, 0)
    }

    // MARK: - Log stamp (NS-11)

    func testLogsCarryTheCurrentValueOnceOneIsKnown() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)

        XCTAssertTrue(recorder.logAttributes.isEmpty)

        monitor.send(wifi: true, at: time(1))

        XCTAssertEqual(recorder.logAttributes["emb.state.network"]?.description, "wifi")
    }

    // MARK: - No value type (NS-12)

    func testValueTypeIsNeverWritten() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
        monitor.send(wifi: true, at: time(1))
        monitor.send(satisfied: false, at: time(2))

        recorder.onSessionPartWillEnd(at: time(60))

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertNil(span.attributes[SpanSemantics.State.keyValueType])
        for event in span.events {
            XCTAssertNil(event.attributes[SpanSemantics.State.keyValueType])
        }
        XCTAssertNil(recorder.logAttributes["emb.state.network.value_type"])
    }

    // MARK: - Threading

    func testUpdatesDeliveredOffTheMainThreadAreRecorded() throws {
        startedService()
        let recorder = try XCTUnwrap(service.recorder)
        recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

        let delivered = expectation(description: "update delivered on a background queue")
        DispatchQueue.global(qos: .utility).async { [monitor] in
            monitor?.send(wifi: true, at: self.time(1))
            monitor?.send(cellular: true, at: self.time(2))
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: .defaultTimeout)

        let span = try XCTUnwrap(stateSpans.first)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "wifi")
        XCTAssertEqual(span.events.count, 1)
    }
}
