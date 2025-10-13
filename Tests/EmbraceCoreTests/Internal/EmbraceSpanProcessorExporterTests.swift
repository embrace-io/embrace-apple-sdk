//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

final class EmbraceSpanProcessorExporterTests: XCTestCase {

    func processor(storage: EmbraceStorage, session: SessionControllable) -> EmbraceSpanProcessor {
        EmbraceSpanProcessor(
            spanExporter: StorageSpanExporter(
                storage: storage,
                logger: MockLogger()
            ),
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
        processor.processCompletedSpanData(closedSpanData)
        processor.processCompletedSpanData(updated_closedSpanData)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = try XCTUnwrap(exportedSpans.first)
        XCTAssertEqual(exportedSpan.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan.id, spanId.hexString)
        XCTAssertEqual(exportedSpan.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(exportedSpan.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.01)

        XCTAssertNotNil(exportedSpan.sessionIdRaw)
        XCTAssertEqual(exportedSpan.sessionIdRaw, sessionController.currentSession?.id?.toString)
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
        processor.processIncompletedSpanData(openSpanData, span: nil, sync: false)
        processor.processIncompletedSpanData(updated_openSpanData, span: nil, sync: false)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

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
        processor.processIncompletedSpanData(openSessionSpan, span: nil, sync: false)
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
        processor.processCompletedSpanData(closedSessionSpan)
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

    func test_name_empty() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController)

        let traceId = TraceId.random()
        let spanId = SpanId.random()

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2000)

        // given a span with an invalid name
        let spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: "    ",
            kind: .internal,
            startTime: startTime,
            attributes: ["emb.type": .string("ux.session")],
            endTime: endTime,
            hasEnded: false
        )

        // when the span is exported
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(spanData)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the data is not exported
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 0)
    }

    func test_name_truncate() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController)

        let traceId = TraceId.random()
        let spanId = SpanId.random()

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2000)

        let name = String(repeating: ".", count: 200)
        XCTAssertEqual(name.count, 200)

        // given a span with a really long name
        let spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            attributes: ["emb.type": .string("ux.session")],
            endTime: endTime,
            hasEnded: false
        )

        // when the span is exported
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(spanData)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the data is exported with a truncated name
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)
        XCTAssertEqual(exportedSpans[0].name.count, 128)
    }

    func test_name_dontTruncate() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let processor = processor(storage: storage, session: sessionController)

        let traceId = TraceId.random()
        let spanId = SpanId.random()

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2000)

        let name = String(repeating: ".", count: 200)
        XCTAssertEqual(name.count, 200)

        // given a network request span with a really long name
        let spanData = SpanData(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: nil,
            name: name,
            kind: .internal,
            startTime: startTime,
            attributes: ["emb.type": .string("perf.network_request")],
            endTime: endTime,
            hasEnded: false
        )

        // when the span is exported
        let expectation = XCTestExpectation()
        processor.processCompletedSpanData(spanData)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .shortTimeout)

        // then the data is exported without truncating the anme
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)
        XCTAssertEqual(exportedSpans[0].name.count, 200)
    }

    func test_addsSessionIdAttribute() throws {
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

        let span = SpanData(
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

        // when an open session span is exported
        let expectation = XCTestExpectation()
        processor.processIncompletedSpanData(span, span: nil, sync: false)
        processor.processorQueue.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .longTimeout)

        // then the session id is added to the exported data
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)

        let spanData = try JSONDecoder().decode(SpanData.self, from: exportedSpans[0].data)
        XCTAssertEqual(spanData.attributes["session.id"], .string(sessionController.currentSession!.idRaw))
    }
}
