//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceStorage
import EmbraceCommon
@testable import EmbraceOTel
import TestSupport
import OpenTelemetryApi
@testable import OpenTelemetrySdk

// swiftlint:disable force_cast

final class SpansPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: SessionRecord!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        sessionRecord = SessionRecord(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: .random,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 50),
            endTime: Date(timeIntervalSince1970: 100)
        )
    }

    override func tearDownWithError() throws {
        try storage.dbQueue.write { db in
            try SessionRecord.deleteAll(db)
            try SpanRecord.deleteAll(db)
        }

        sessionRecord = nil

        try storage.teardown()
    }

    func testSpan(startTime: Date, endTime: Date?, name: String?) -> SpanData {
        return SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: name ?? "test-span",
            kind: .internal,
            startTime: startTime,
            endTime: endTime ?? Date(),
            hasEnded: endTime != nil
        )
    }

    func addSpan(
        startTime: Date,
        endTime: Date?,
        id: String? = nil,
        traceId: String? = nil,
        name: String? = nil,
        type: SpanType = .performance
    ) throws -> SpanData {
        let spanData = testSpan(startTime: startTime, endTime: endTime, name: name)
        let data = try spanData.toJSON()

        let record = SpanRecord(
            id: id ?? spanData.spanId.hexString,
            name: spanData.name,
            traceId: traceId ?? spanData.traceId.hexString,
            type: type,
            data: data,
            startTime: spanData.startTime,
            endTime: spanData.hasEnded ? spanData.endTime : nil
        )

        try storage.upsertSpan(record)

        return spanData
    }

    func test_noSessionSpan() throws {
        // given no session span and a session record with nil end time
        let record = SessionRecord(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: .random,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 50),
            endTime: nil,
            lastHeartbeatTime: Date(timeIntervalSince1970: 100)
        )

        // when building the spans payload
        let (closed, _) = SpansPayloadBuilder.build(for: record, storage: storage)

        // then a session span is created
        // and its end time is valid
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName)
        XCTAssertEqual(closed[0].endTime, record.lastHeartbeatTime.nanosecondsSince1970Truncated)
    }

    func test_sessionSpan_withNoEndTime() throws {
        // given a session span with no end time
        _ = try addSpan(
            startTime: Date(timeIntervalSince1970: 5),
            endTime: nil,
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "emb-session",
            type: SpanType.session
        )

        // when building the spans payload
        let (closed, _) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then session span has an end time
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName)
        XCTAssertNotNil(closed[0].endTime)
        XCTAssertEqual(closed[0].endTime, sessionRecord.endTime!.nanosecondsSince1970Truncated)
    }

    func test_closedSpan() throws {
        // given a closed span within a session time frame
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 55),
            endTime: Date(timeIntervalSince1970: 60)
        )
        let payload = SpanPayload(from: span)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 2)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(open.count, 0)
    }

    func test_openSpan_withinSession() throws {
        // given a open span that started after the session
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 55),
            endTime: nil
        )
        let payload = SpanPayload(from: span)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open[0], payload)
    }

    func test_closedSpan_beforeSession() throws {
        // given a closed span that started before the session, and ended in the session
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 55)
        )
        let payload = SpanPayload(from: span)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 2)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(open.count, 0)
    }

    func test_openSpan_beforeSession() throws {
        // given a open span that started before the session
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: nil
        )
        let payload = SpanPayload(from: span)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open[0], payload)
    }

    func test_closedSpan_outsideSession() throws {
        // given a closed span that started and ended before the session
        _ = try addSpan(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 10)
        )

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_openSpan_withinCrashedSession() throws {
        // given a crashed session
        sessionRecord.crashReportId = "test"

        // given a open span that started after the crashed session
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 55),
            endTime: nil
        )
        let payload = SpanPayload(from: span, endTime: sessionRecord.endTime, failed: true)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 2)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(open.count, 0)

        // then the error code attribute was added
        let attribute = closed[1].attributes.first { $0.key == "emb.error_code" }
        XCTAssertEqual(attribute!.value, "failure")
    }

    func test_openSpan_beforeCrashedSession() throws {
        // given a crashed session
        sessionRecord.crashReportId = "test"

        // given a open span that started before the crashed session
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: nil
        )
        let payload = SpanPayload(from: span, endTime: sessionRecord.endTime, failed: true)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 2)
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(open.count, 0)

        // then the error code attribute was added
        let attribute = closed[1].attributes.first { $0.key == "emb.error_code" }
        XCTAssertEqual(attribute!.value, "failure")
    }

    func test_hardLimit() throws {
        // given more than 1000 spans
        for _ in 1...1100 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60)
            )
        }

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 1001) // 1000 spans + session span
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_multiple_session_spans() throws {
        // given multiple session spans
        _ = try addSpan(
            startTime: Date(timeIntervalSince1970: 5),
            endTime: Date(timeIntervalSince1970: 55),
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "emb-session",
            type: SpanType.session
        )

        _ = try addSpan(
            startTime: Date(timeIntervalSince1970: 5),
            endTime: Date(timeIntervalSince1970: 55),
            name: "emb-session",
            type: SpanType.session
        )

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then only the correct session span is included
        XCTAssertEqual(closed.count, 1) // 1000 spans + session span
        XCTAssertEqual(closed[0].name, SessionSpanUtils.spanName) // session span always first
        XCTAssertEqual(open.count, 0)
    }
}

// swiftlint:enable force_cast
