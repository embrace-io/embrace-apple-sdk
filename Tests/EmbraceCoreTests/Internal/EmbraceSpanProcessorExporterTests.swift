//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import EmbraceStorageInternal
@testable import OpenTelemetrySdk

final class EmbraceSpanProcessorExporterTests: XCTestCase {

    func processor(storage: EmbraceStorage, session: SessionControllable, useNewStorage: Bool = false) -> EmbraceSpanProcessor {
        EmbraceSpanProcessor(
            spanExporters: [
                StorageSpanExporter(
                    storage: storage,
                    logger: MockLogger(),
                    useNewStorage: useNewStorage
                )
            ],
            sdkStateProvider: MockEmbraceSDKStateProvider(),
            sessionIdProvider: { session.currentSession?.idRaw }
        )
    }

    func test_DB_preventsClosedSpan_fromUpdatingEndTime() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "target_span"

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2000)

        let closedSpanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            endTime: endTime,
            hasEnded: true
        )

        let updated_closedSpanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime.addingTimeInterval(1000),
            endTime: startTime.addingTimeInterval(-10000),
            hasEnded: false
        )

        // When spans are exported
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(closedSpanData, sync: true)
        processor.processCompletedSpanData(updated_closedSpanData, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .longTimeout)

        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = try XCTUnwrap(exportedSpans.first)
        XCTAssertEqual(exportedSpan.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan.id, spanId.hexString)
        XCTAssertEqual(exportedSpan.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(exportedSpan.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.01)
    }

    func test_DB_allowsOpenSpan_toUpdateAttributes() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "target_span"

        let startTime = Date()

        let openSpanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            attributes: ["foo": .string("bar")],
            endTime: Date(),
            hasEnded: false
        )

        let updated_openSpanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime.addingTimeInterval(1000),
            attributes: ["foo": .string("baz")],
            endTime: Date(),
            hasEnded: false
        )

        // When spans are exported
        let expectation = XCTestExpectation()
        processor.processIncompletedSpanData(openSpanData, span: nil, sync: true)
        processor.processIncompletedSpanData(updated_openSpanData, span: nil, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .longTimeout)

        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = exportedSpans.first
        XCTAssertEqual(exportedSpan?.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan?.id, spanId.hexString)

        let spanData = try JSONDecoder().decode(SpanData.self, from: exportedSpan!.data)
        XCTAssertEqual(spanData.attributes["foo"], .string("baz"))
    }

    func test_noExport_onSessionEnd() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "target_span"

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2000)

        let openSessionSpan = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            attributes: ["emb.type": .string("perf")],
            endTime: endTime,
            hasEnded: false
        )

        let closedSessionSpan = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            attributes: ["emb.type": .string("perf")],
            endTime: endTime,
            hasEnded: true
        )

        // when an open session span is exported
        let expectation = XCTestExpectation()
        processor.processIncompletedSpanData(openSessionSpan, span: nil, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the data is exported
        var exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)
        XCTAssertNil(exportedSpans[0].endTime)

        // when a closed session span is exported
        let expectation1 = XCTestExpectation()
        processor.processCompletedSpanData(closedSessionSpan, sync: true)
        processor.processorQueue.async {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: .shortTimeout)

        // then the data is NOT exported
        exportedSpans = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)
        XCTAssertNotNil(exportedSpans[0].endTime)
    }

    // MARK: - New Storage for Events Tests

    func test_newStorageForEvents_eventsAreStoredSeparately() throws {
        // given a storage and processor with new storage enabled
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController, useNewStorage: true)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "test_span"

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1000)

        // given a span with events
        let event1 = SpanData.Event(name: "event1", timestamp: startTime.addingTimeInterval(100), attributes: ["key1": .string("value1")])
        let event2 = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(200), attributes: ["key2": .string("value2")])

        let spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1, event2],
            endTime: endTime,
            hasEnded: true
        )

        // when the span is exported
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(spanData)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the span is stored
        let exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertNotNil(exportedSpan)
        XCTAssertEqual(exportedSpan?.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan?.id, spanId.hexString)

        // and the events are stored separately in the events relationship
        XCTAssertEqual(exportedSpan?.events.count, 2)

        let sortedEvents = (exportedSpan?.events ?? []).sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(sortedEvents[0].name, "event1")
        XCTAssertEqual(sortedEvents[0].attributes["key1"], "value1")
        XCTAssertEqual(sortedEvents[1].name, "event2")
        XCTAssertEqual(sortedEvents[1].attributes["key2"], "value2")

        // and the events are removed from the SpanData (verify by fetching the raw record)
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        let rawSpanRecord = exportedSpans.first { $0.id == spanId.hexString }
        let decodedSpanData = try JSONDecoder().decode(SpanData.self, from: rawSpanRecord!.data)
        XCTAssertEqual(decodedSpanData.events.count, 0)
    }

    func test_newStorageForEvents_preventsDuplicateEvents() throws {
        // given a storage and processor with new storage enabled
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController, useNewStorage: true)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "test_span"

        let startTime = Date()

        // given a span with one event
        let event1 = SpanData.Event(name: "event1", timestamp: startTime.addingTimeInterval(100), attributes: ["key1": .string("value1")])

        let spanData1 = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1],
            endTime: Date(),
            hasEnded: false
        )

        // when the span is exported first time
        let expectation1 = XCTestExpectation()
        processor.processIncompletedSpanData(spanData1, span: nil, sync: true)
        processor.processorQueue.async {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: .shortTimeout)

        // then one event is stored
        var exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertEqual(exportedSpan?.events.count, 1)

        // given the same span with a new event added
        let event2 = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(200), attributes: ["key2": .string("value2")])

        let spanData2 = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1, event2],
            endTime: Date(),
            hasEnded: false
        )

        // when the span is exported again
        let expectation2 = XCTestExpectation()
        processor.processIncompletedSpanData(spanData2, span: nil, sync: true)
        processor.processorQueue.async {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: .shortTimeout)

        // then only the new event is added (no duplicate of event1)
        exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertEqual(exportedSpan?.events.count, 2)

        let sortedEvents = (exportedSpan?.events ?? []).sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(sortedEvents[0].name, "event1")
        XCTAssertEqual(sortedEvents[1].name, "event2")
    }

    func test_oldStorage_eventsAreInSpanData() throws {
        // given a storage and processor with old storage (new storage disabled)
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController, useNewStorage: false)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "test_span"

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1000)

        // given a span with events
        let event1 = SpanData.Event(name: "event1", timestamp: startTime.addingTimeInterval(100), attributes: ["key1": .string("value1")])
        let event2 = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(200), attributes: ["key2": .string("value2")])

        let spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1, event2],
            endTime: endTime,
            hasEnded: true
        )

        // when the span is exported
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(spanData)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the span is stored
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(exportedSpans.count, 1)

        let exportedSpan = exportedSpans[0]
        XCTAssertEqual(exportedSpan.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan.id, spanId.hexString)

        // and the events are NOT stored separately (old behavior)
        XCTAssertEqual(exportedSpan.events.count, 0)

        // and the events are still in the SpanData
        let decodedSpanData = try JSONDecoder().decode(SpanData.self, from: exportedSpan.data)
        XCTAssertEqual(decodedSpanData.events.count, 2)
        XCTAssertEqual(decodedSpanData.events[0].name, "event1")
        XCTAssertEqual(decodedSpanData.events[1].name, "event2")
    }

    // MARK: - Full Lifecycle Integration Tests

    func test_fullLifecycle_withNewStorage_spanCreationToPayloadBuild() throws {
        // given a storage and processor with new storage enabled
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController, useNewStorage: true)

        let session = sessionController.currentSession!

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "integration_test_span"

        let startTime = session.startTime.addingTimeInterval(10)
        let endTime = startTime.addingTimeInterval(100)

        // given a span with events
        let event1 = SpanData.Event(
            name: "lifecycle_event1",
            timestamp: startTime.addingTimeInterval(10),
            attributes: ["stage": .string("start"), "value": .int(42)]
        )
        let event2 = SpanData.Event(
            name: "lifecycle_event2",
            timestamp: startTime.addingTimeInterval(50),
            attributes: ["stage": .string("middle"), "value": .int(100)]
        )
        let event3 = SpanData.Event(
            name: "lifecycle_event3",
            timestamp: startTime.addingTimeInterval(90),
            attributes: ["stage": .string("end"), "value": .int(200)]
        )

        let spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1, event2, event3],
            endTime: endTime,
            hasEnded: true
        )

        // when the span is exported through the processor
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(spanData, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the span is stored with events in separate storage
        let exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertNotNil(exportedSpan)
        XCTAssertEqual(exportedSpan?.id, spanId.hexString)
        XCTAssertEqual(exportedSpan?.events.count, 3)

        // verify events are stored correctly
        let sortedEvents = (exportedSpan?.events ?? []).sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(sortedEvents[0].name, "lifecycle_event1")
        XCTAssertEqual(sortedEvents[1].name, "lifecycle_event2")
        XCTAssertEqual(sortedEvents[2].name, "lifecycle_event3")

        // when building the payload using SpansPayloadBuilder
        let mockSession = MockSession(
            id: session.id!,
            processId: session.processId!,
            state: .foreground,
            traceId: session.traceId,
            spanId: session.spanId,
            startTime: session.startTime,
            endTime: session.startTime.addingTimeInterval(1000)
        )

        let (closedPayloads, _) = SpansPayloadBuilder.build(for: mockSession, storage: storage)

        // then the payload includes the span with all events from separate storage
        XCTAssertTrue(closedPayloads.count >= 2)  // session span + our test span

        let spanPayload = closedPayloads.first { $0.name == name }
        XCTAssertNotNil(spanPayload)
        XCTAssertEqual(spanPayload!.events.count, 3)

        // verify events in payload
        XCTAssertEqual(spanPayload!.events[0].name, "lifecycle_event1")
        XCTAssertEqual(spanPayload!.events[1].name, "lifecycle_event2")
        XCTAssertEqual(spanPayload!.events[2].name, "lifecycle_event3")

        // verify event attributes in payload
        let event1Attrs = spanPayload!.events[0].attributes
        XCTAssertTrue(event1Attrs.contains { $0.key == "stage" && $0.value == "start" })
        XCTAssertTrue(event1Attrs.contains { $0.key == "value" && $0.value == "42" })

        let event3Attrs = spanPayload!.events[2].attributes
        XCTAssertTrue(event3Attrs.contains { $0.key == "stage" && $0.value == "end" })
        XCTAssertTrue(event3Attrs.contains { $0.key == "value" && $0.value == "200" })
    }

    func test_fullLifecycle_multipleSpanUpdates_withNewStorage() throws {
        // given a storage and processor with new storage enabled
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController, useNewStorage: true)

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "multi_update_span"

        let startTime = Date()

        // when exporting the span multiple times with different events (simulating span updates)
        // first export with 1 event
        let event1 = SpanData.Event(name: "event1", timestamp: startTime.addingTimeInterval(10), attributes: [:])
        var spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1],
            endTime: Date(),
            hasEnded: false
        )

        var expectation = XCTestExpectation()
        processor.processIncompletedSpanData(spanData, span: nil, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // verify 1 event stored
        var exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertEqual(exportedSpan?.events.count, 1)

        // second export with 2 events (event1 + event2)
        let event2 = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(20), attributes: [:])
        spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1, event2],
            endTime: Date(),
            hasEnded: false
        )

        expectation = XCTestExpectation()
        processor.processIncompletedSpanData(spanData, span: nil, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // verify 2 events stored (no duplicate of event1)
        exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertEqual(exportedSpan?.events.count, 2)

        // third export with 3 events (event1 + event2 + event3)
        let event3 = SpanData.Event(name: "event3", timestamp: startTime.addingTimeInterval(30), attributes: [:])
        spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            events: [event1, event2, event3],
            endTime: Date(),
            hasEnded: false
        )

        expectation = XCTestExpectation()
        processor.processIncompletedSpanData(spanData, span: nil, sync: true)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then all 3 events are stored without duplicates
        exportedSpan = storage.fetchSpan(id: spanId.hexString, traceId: traceId.hexString)
        XCTAssertEqual(exportedSpan?.events.count, 3)

        let sortedEvents = (exportedSpan?.events ?? []).sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(sortedEvents[0].name, "event1")
        XCTAssertEqual(sortedEvents[1].name, "event2")
        XCTAssertEqual(sortedEvents[2].name, "event3")
    }
}
