//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

final class SpansPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: MockSession!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        sessionRecord = MockSession(
            id: TestConstants.sessionId,
            processId: .random,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 50),
            endTime: Date(timeIntervalSince1970: 100)
        )
    }

    override func tearDownWithError() throws {
        sessionRecord = nil
        storage.coreData.destroy()
    }

    func testSpan(startTime: Date, endTime: Date?, name: String?) -> SpanData {
        return SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: name ?? "test-span",
            kind: .internal,
            startTime: startTime,
            status: endTime == nil ? .unset : .ok,
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

        storage.upsertSpan(
            id: id ?? spanData.spanId.hexString,
            name: spanData.name,
            traceId: traceId ?? spanData.traceId.hexString,
            type: type,
            data: data,
            startTime: spanData.startTime,
            endTime: spanData.hasEnded ? spanData.endTime : nil
        )

        return spanData
    }

    func test_noSessionSpan() throws {
        // given no session span and a session record with nil end time
        let record = MockSession(
            id: TestConstants.sessionId,
            processId: .random,
            state: .foreground,
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
        XCTAssertEqual(closed[0].name, "emb-session")
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
        XCTAssertEqual(closed[0].name, "emb-session")
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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_openSpan_withinCrashedSession() throws {
        // given a crashed session
        sessionRecord = sessionRecord.copyWithCrashReportId("test")

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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(closed[0].status, "error")
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(closed[1].status, "error")
        XCTAssertEqual(open.count, 0)

        // then the error code attribute was added
        let attribute = closed[1].attributes.first { $0.key == "emb.error_code" }
        XCTAssertEqual(attribute!.value, "failure")
    }

    func test_openSpan_beforeCrashedSession() throws {
        // given a crashed session
        sessionRecord = sessionRecord.copyWithCrashReportId("test")

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
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(closed[0].status, "error")
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(closed[1].status, "error")
        XCTAssertEqual(open.count, 0)

        // then the error code attribute was added
        let attribute = closed[1].attributes.first { $0.key == "emb.error_code" }
        XCTAssertEqual(attribute!.value, "failure")
    }

    func test_closedSpan_withinCrashedSession() throws {
        // given a crashed session
        sessionRecord = sessionRecord.copyWithCrashReportId("test")

        // given a open span that started after the crashed session
        let span = try addSpan(
            startTime: Date(timeIntervalSince1970: 55),
            endTime: Date(timeIntervalSince1970: 60)
        )
        let payload = SpanPayload(from: span, endTime: Date(timeIntervalSince1970: 60), failed: false)

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 2)
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(closed[0].status, "error")
        XCTAssertEqual(closed[1], payload)
        XCTAssertEqual(closed[1].status, "ok")
        XCTAssertEqual(open.count, 0)

        // then the error code attribute was added
        let attribute = closed[1].attributes.first { $0.key == "emb.error_code" }
        XCTAssertNil(attribute)
    }

    func test_hardLimit() throws {

        let oldLimits = storage.options.spanLimits
        storage.options.spanLimits = [
            .performance: 10,
            .ux: 10,
            .system: 10
        ]
        defer {
            storage.options.spanLimits = oldLimits
        }

        // given more than 1000 spans
        for _ in 1...16 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .performance
            )
        }

        for _ in 1...16 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .ux
            )
        }

        for _ in 1...16 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .system
            )
        }

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 31)  // 30 spans + 1 session
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_hardLimit_Type_Performance() throws {

        let oldLimits = storage.options.spanLimits
        storage.options.spanLimits = [
            .performance: 10,
            .ux: 10,
            .system: 10
        ]
        defer {
            storage.options.spanLimits = oldLimits
        }

        // given more than 500 spans
        for _ in 1...16 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .performance
            )
        }

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 11)  // 10 spans + session span
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_hardLimit_Type_UX() throws {

        let oldLimits = storage.options.spanLimits
        storage.options.spanLimits = [
            .performance: 10,
            .ux: 10,
            .system: 10
        ]
        defer {
            storage.options.spanLimits = oldLimits
        }

        // given more than 1500 spans
        for _ in 1...16 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .ux
            )
        }

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 11)  // 10 spans + session span
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_hardLimit_Type_System() throws {

        let oldLimits = storage.options.spanLimits
        storage.options.spanLimits = [
            .performance: 10,
            .ux: 10,
            .system: 10
        ]
        defer {
            storage.options.spanLimits = oldLimits
        }

        // given more than 1500 spans
        for _ in 1...16 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .system
            )
        }

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 11)  // 10 spans + session span
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(open.count, 0)
    }

    func test_hardLimits_withSecondaryType() throws {

        let oldLimits = storage.options.spanLimits
        let oldLimitDefault = storage.options.spanLimitDefault
        storage.options.spanLimits = [
            .performance: 10,
            .ux: 10,
            .system: 10
        ]
        storage.options.spanLimitDefault = 10
        defer {
            storage.options.spanLimits = oldLimits
            storage.options.spanLimitDefault = oldLimitDefault
        }

        // given more than 800 spans
        for _ in 1...6 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .init(ux: "Test_1")
            )
        }

        for _ in 1...6 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .init(ux: "Test_2")
            )
        }

        for _ in 1...6 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .init(system: "Test_1")
            )
        }

        for _ in 1...6 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .init(system: "Test_2")
            )
        }

        for _ in 1...6 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .init(performance: "Test_1")
            )
        }

        for _ in 1...6 {
            _ = try addSpan(
                startTime: Date(timeIntervalSince1970: 55),
                endTime: Date(timeIntervalSince1970: 60),
                type: .init(performance: "Test_2")
            )
        }

        // when building the spans payload
        let (closed, open) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the spans are retrieved correctly
        XCTAssertEqual(closed.count, 31)  // 30 spans + session span
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
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
        XCTAssertEqual(closed.count, 1)  // 1000 spans + session span
        XCTAssertEqual(closed[0].name, "emb-session")  // session span always first
        XCTAssertEqual(open.count, 0)
    }

    // MARK: - New Storage for Events Tests

    func test_payloadBuilder_retrievesEventsFromSeparateStorage() throws {
        // given a span stored with events in separate storage (new storage mechanism)
        let spanData = testSpan(
            startTime: Date(timeIntervalSince1970: 55),
            endTime: Date(timeIntervalSince1970: 60),
            name: "test-span"
        )

        // store span data WITHOUT events (simulating new storage mechanism)
        let spanDataWithoutEvents = spanData.spanDataByRemovingEvents()
        let data = try spanDataWithoutEvents.toJSON()

        storage.upsertSpan(
            id: spanData.spanId.hexString,
            name: spanData.name,
            traceId: spanData.traceId.hexString,
            type: .performance,
            data: data,
            startTime: spanData.startTime,
            endTime: spanData.endTime
        )

        // add events separately to storage
        let event1 = ImmutableSpanEventRecord(
            name: "event1",
            timestamp: Date(timeIntervalSince1970: 56),
            attributes: ["key1": "value1"]
        )
        let event2 = ImmutableSpanEventRecord(
            name: "event2",
            timestamp: Date(timeIntervalSince1970: 57),
            attributes: ["key2": "value2"]
        )
        storage.addEventsToSpan(
            id: spanData.spanId.hexString,
            traceId: spanData.traceId.hexString,
            events: [event1, event2]
        )

        // when building the spans payload
        let (closed, _) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the payload includes events from separate storage
        XCTAssertEqual(closed.count, 2)  // session span + test span
        XCTAssertEqual(closed[0].name, "emb-session")

        let spanPayload = closed[1]
        XCTAssertEqual(spanPayload.name, "test-span")
        XCTAssertEqual(spanPayload.events.count, 2)
        XCTAssertEqual(spanPayload.events[0].name, "event1")
        XCTAssertEqual(spanPayload.events[1].name, "event2")

        // verify event attributes
        let event1Attrs = spanPayload.events[0].attributes
        XCTAssertTrue(event1Attrs.contains { $0.key == "key1" && $0.value == "value1" })

        let event2Attrs = spanPayload.events[1].attributes
        XCTAssertTrue(event2Attrs.contains { $0.key == "key2" && $0.value == "value2" })
    }

    func test_payloadBuilder_usesSpanDataEventsWhenPresent() throws {
        // given a span stored with events in SpanData (old storage mechanism)
        let event1 = SpanData.Event(
            name: "event1",
            timestamp: Date(timeIntervalSince1970: 56),
            attributes: ["key1": .string("value1")]
        )
        let event2 = SpanData.Event(
            name: "event2",
            timestamp: Date(timeIntervalSince1970: 57),
            attributes: ["key2": .string("value2")]
        )

        let spanData = SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: "test-span",
            kind: .internal,
            startTime: Date(timeIntervalSince1970: 55),
            events: [event1, event2],
            endTime: Date(timeIntervalSince1970: 60),
            hasEnded: true
        )

        // store span data WITH events (old storage mechanism)
        let data = try spanData.toJSON()

        storage.upsertSpan(
            id: spanData.spanId.hexString,
            name: spanData.name,
            traceId: spanData.traceId.hexString,
            type: .performance,
            data: data,
            startTime: spanData.startTime,
            endTime: spanData.endTime
        )

        // when building the spans payload
        let (closed, _) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the payload uses events from SpanData
        XCTAssertEqual(closed.count, 2)  // session span + test span
        XCTAssertEqual(closed[0].name, "emb-session")

        let spanPayload = closed[1]
        XCTAssertEqual(spanPayload.name, "test-span")
        XCTAssertEqual(spanPayload.events.count, 2)
        XCTAssertEqual(spanPayload.events[0].name, "event1")
        XCTAssertEqual(spanPayload.events[1].name, "event2")
    }

    func test_payloadBuilder_prefersSpanDataEventsOverSeparateStorage() throws {
        // given a span with events in both SpanData and separate storage
        let spanDataEvent = SpanData.Event(
            name: "spandata_event",
            timestamp: Date(timeIntervalSince1970: 56),
            attributes: ["source": .string("spandata")]
        )

        let spanData = SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: "test-span",
            kind: .internal,
            startTime: Date(timeIntervalSince1970: 55),
            events: [spanDataEvent],
            endTime: Date(timeIntervalSince1970: 60),
            hasEnded: true
        )

        // store span data WITH events
        let data = try spanData.toJSON()

        storage.upsertSpan(
            id: spanData.spanId.hexString,
            name: spanData.name,
            traceId: spanData.traceId.hexString,
            type: .performance,
            data: data,
            startTime: spanData.startTime,
            endTime: spanData.endTime
        )

        // also add an event to separate storage (shouldn't be used)
        let separateEvent = ImmutableSpanEventRecord(
            name: "separate_event",
            timestamp: Date(timeIntervalSince1970: 57),
            attributes: ["source": "separate"]
        )
        storage.addEventsToSpan(
            id: spanData.spanId.hexString,
            traceId: spanData.traceId.hexString,
            events: [separateEvent]
        )

        // when building the spans payload
        let (closed, _) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the payload prefers events from SpanData over separate storage
        XCTAssertEqual(closed.count, 2)  // session span + test span
        XCTAssertEqual(closed[0].name, "emb-session")

        let spanPayload = closed[1]
        XCTAssertEqual(spanPayload.name, "test-span")
        XCTAssertEqual(spanPayload.events.count, 1)
        XCTAssertEqual(spanPayload.events[0].name, "spandata_event")

        // verify it's from SpanData, not separate storage
        let attrs = spanPayload.events[0].attributes
        XCTAssertTrue(attrs.contains { $0.key == "source" && $0.value == "spandata" })
    }

    func test_payloadBuilder_sessionSpan_retrievesEventsFromSeparateStorage() throws {
        // given a session span with events in separate storage
        // Use the sessionRecord's traceId and spanId which are valid
        let sessionTraceId = TraceId(fromHexString: sessionRecord.traceId)
        let sessionSpanId = SpanId(fromHexString: sessionRecord.spanId)

        let sessionSpanData = SpanData(
            traceId: sessionTraceId,
            spanId: sessionSpanId,
            parentSpanId: nil,
            name: "emb-session",
            kind: .internal,
            startTime: sessionRecord.startTime,
            endTime: sessionRecord.endTime!,
            hasEnded: true
        )

        // store session span WITHOUT events
        let spanDataWithoutEvents = sessionSpanData.spanDataByRemovingEvents()
        let data = try spanDataWithoutEvents.toJSON()

        storage.upsertSpan(
            id: sessionRecord.spanId,
            name: "emb-session",
            traceId: sessionRecord.traceId,
            type: .session,
            data: data,
            startTime: sessionSpanData.startTime,
            endTime: sessionSpanData.endTime
        )

        // add events separately to storage
        let event1 = ImmutableSpanEventRecord(
            name: "session_event1",
            timestamp: Date(timeIntervalSince1970: 60),
            attributes: ["type": "session_info"]
        )
        storage.addEventsToSpan(
            id: sessionRecord.spanId,
            traceId: sessionRecord.traceId,
            events: [event1]
        )

        // when building the spans payload
        let (closed, _) = SpansPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the session span payload includes events from separate storage
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed[0].name, "emb-session")
        XCTAssertEqual(closed[0].events.count, 1)
        XCTAssertEqual(closed[0].events[0].name, "session_event1")

        let attrs = closed[0].events[0].attributes
        XCTAssertTrue(attrs.contains { $0.key == "type" && $0.value == "session_info" })
    }
}
