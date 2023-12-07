//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
import EmbraceStorage
import EmbraceCommon
@testable import EmbraceOTel
import TestSupport
import OpenTelemetryApi

final class SpansPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: SessionRecord!

    override func setUpWithError() throws {
        storage = try EmbraceStorage(options: .init(named: #file))

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
    }

    func testSpan(startTime: Date, endTime: Date?) -> SpanData {
        return SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: "test-span",
            kind: .internal,
            startTime: startTime,
            endTime: endTime
        )
    }

    func addSpan(startTime: Date, endTime: Date?) throws -> SpanData {
        let span = testSpan(startTime: startTime, endTime: endTime)
        let data = try span.toJSON()

        let record = SpanRecord(
            id: span.spanId.hexString,
            name: span.name,
            traceId: span.traceId.hexString,
            type: .performance,
            data: data,
            startTime: span.startTime,
            endTime: span.endTime
        )

        try storage.upsertSpan(record)

        return span
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
}
