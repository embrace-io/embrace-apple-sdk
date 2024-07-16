//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCaptureService
import TestSupport
import EmbraceOTelInternal

class MockCaptureService: CaptureService {
    var installCalled = false
    override func onInstall() {
        installCalled = true
    }

    var startCalled = false
    override func onStart() {
        startCalled = true
    }

    var stopCalled = false
    override func onStop() {
        stopCalled = true
    }
}

class CaptureServiceTests: XCTestCase {

    func test_initialState() throws {
        // given a capture service
        let service = CaptureService()

        // then the initial state is correct
        XCTAssertEqual(service.state, .uninstalled)
    }

    func test_installed() throws {
        // given a capture service
        let service = CaptureService()

        // when installing it
        service.install(otel: nil)

        // then the initial state is correct
        XCTAssertEqual(service.state, .installed)
    }

    func test_active() throws {
        // given a capture service
        let service = CaptureService()

        // when installing and starting it
        service.install(otel: nil)
        service.start()

        // then the initial state is correct
        XCTAssertEqual(service.state, .active)
    }

    func test_paused() throws {
        // given a capture service
        let service = CaptureService()

        // when installing, starting and stopping it
        service.install(otel: nil)
        service.start()
        service.stop()

        // then the initial state is correct
        XCTAssertEqual(service.state, .paused)
    }

    func test_internalCalls() throws {
        // given a capture service
        let service = MockCaptureService()

        // when installing it
        service.install(otel: nil)

        // then onInstall is called
        XCTAssertTrue(service.installCalled)

        // when starting it
        service.start()

        // then onStart is called
        XCTAssertTrue(service.startCalled)

        // when stopping it
        service.stop()

        // then onStop is called
        XCTAssertTrue(service.stopCalled)
    }

    func test_startSpan() throws {
        // given a started capture service
        let otel = MockEmbraceOpenTelemetry()
        let service = MockCaptureService()
        service.install(otel: otel)
        service.start()

        // when starting a span
        let builder = service.buildSpan(name: "test", type: .performance, attributes: ["key": "value"])
        _ = builder!.startSpan()

        // then the span is correctly started
        let span = otel.spanProcessor.startedSpans[0]
        XCTAssertEqual(span.name, "test")
        XCTAssertEqual(span.embType, .performance)
        XCTAssertEqual(span.attributes["key"], .string("value"))
    }

    func test_endSpan() throws {
        // given a started capture service
        let otel = MockEmbraceOpenTelemetry()
        let service = MockCaptureService()
        service.install(otel: otel)
        service.start()

        // when starting and ending a span
        let builder = service.buildSpan(name: "test", type: .performance, attributes: ["key": "value"])
        let original = builder!.startSpan()
        original.end()

        // then the span is correctly started
        let span = otel.spanProcessor.endedSpans[0]
        XCTAssertEqual(span.name, "test")
        XCTAssertEqual(span.embType, .performance)
        XCTAssertEqual(span.attributes["key"], .string("value"))
        XCTAssertNotNil(span.endTime)
    }

    func test_addEvent() throws {
        // given a started capture service
        let otel = MockEmbraceOpenTelemetry()
        let service = MockCaptureService()
        service.install(otel: otel)
        service.start()

        // when adding an event
        service.add(event: RecordingSpanEvent(name: "test", timestamp: Date()))

        // then the event is correctly added
        XCTAssertEqual(otel.events.count, 1)
        XCTAssertEqual(otel.events[0].name, "test")
    }

    func test_addEvents() throws {
        // given a started capture service
        let otel = MockEmbraceOpenTelemetry()
        let service = MockCaptureService()
        service.install(otel: otel)
        service.start()

        // when adding events
        service.add(events: [
            RecordingSpanEvent(name: "test1", timestamp: Date()),
            RecordingSpanEvent(name: "test2", timestamp: Date()),
            RecordingSpanEvent(name: "test3", timestamp: Date())
        ])

        // then the events are correctly added
        XCTAssertEqual(otel.events.count, 3)
        XCTAssertEqual(otel.events[0].name, "test1")
        XCTAssertEqual(otel.events[1].name, "test2")
        XCTAssertEqual(otel.events[2].name, "test3")
    }
}
