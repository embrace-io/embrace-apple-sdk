//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceStorageInternal
import OpenTelemetryApi
import TestSupport
import XCTest
@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

final class StorageSpanExporterTests: XCTestCase {
    func test_DB_preventsClosedSpan_fromUpdatingEndTime() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
        _ = exporter.export(spans: [closedSpanData])
        _ = exporter.export(spans: [updated_closedSpanData])

        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = try XCTUnwrap(exportedSpans.first)
        XCTAssertEqual(exportedSpan.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan.id, spanId.hexString)
        XCTAssertEqual(exportedSpan.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(exportedSpan.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.01)

        XCTAssertNotNil(exportedSpan.sessionIdRaw)
        XCTAssertEqual(exportedSpan.sessionIdRaw, sessionController.currentSession?.id.stringValue)
    }

    func test_DB_allowsOpenSpan_toUpdate() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
        _ = exporter.export(spans: [openSpanData])
        _ = exporter.export(spans: [updated_openSpanData])

        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = exportedSpans.first
        XCTAssertEqual(exportedSpan?.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan?.id, spanId.hexString)

        XCTAssertNotNil(exportedSpan!.sessionIdRaw)
        XCTAssertEqual(exportedSpan!.sessionIdRaw, sessionController.currentSession?.id.stringValue)

        XCTAssert(exportedSpan!.attributes.contains("foo,baz"))
    }

    func test_noExport_onSessionEnd() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
            attributes: ["emb.type": .string("ux.session")],
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
            attributes: ["emb.type": .string("ux.session")],
            endTime: endTime,
            hasEnded: true
        )

        // when an open session span is exported
        _ = exporter.export(spans: [openSessionSpan])

        // then the data is exported
        var exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)
        XCTAssertNil(exportedSpans[0].endTime)

        // when a closed session span is exported
        _ = exporter.export(spans: [closedSessionSpan])

        // then the data is NOT exported
        exportedSpans = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)
        XCTAssertNil(exportedSpans[0].endTime)
    }

    func test_name_empty() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
        _ = exporter.export(spans: [spanData])

        // then the data is not exported
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 0)
    }

    func test_name_truncate() throws {
        // given an exporter
        let storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
        _ = exporter.export(spans: [spanData])

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
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
        _ = exporter.export(spans: [spanData])

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
        let exporter = StorageSpanExporter(
            options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

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
        _ = exporter.export(spans: [span])

        // then the session id is added to the exported data
        let exportedSpans: [SpanRecord] = storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)
        XCTAssertEqual(exportedSpans[0].traceId, traceId.hexString)
        XCTAssertEqual(exportedSpans[0].id, spanId.hexString)

        XCTAssert(exportedSpans[0].attributes.contains("session.id,\(sessionController.currentSession!.id.stringValue)"))
    }
}
