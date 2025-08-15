//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi
import TestSupport
import XCTest
import EmbraceSemantics
@testable import EmbraceStorageInternal

extension Date {
    fileprivate static func relative(_ interval: TimeInterval, from reference: Date = Date()) -> Date {
        reference.addingTimeInterval(interval)
    }
}

final class EmbraceStorage_SpanForSessionRecordTests: XCTestCase {

    // MARK: - Setup
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

    func addSpanRecord(
        type: EmbraceType = .performance,
        name: String = "example",
        processIdentifier: EmbraceIdentifier = ProcessIdentifier.current,
        startTime: Date,
        endTime: Date? = nil,
        sessionIdentifier: EmbraceIdentifier? = nil
    ) -> EmbraceSpan {
        return storage.upsertSpan(
            id: SpanId.random().hexString,
            traceId: TraceId.random().hexString,
            parentSpanId: nil,
            name: name,
            type: type,
            status: .unset,
            startTime: startTime,
            endTime: endTime,
            sessionId: sessionIdentifier,
            processId: processIdentifier
        )!
    }

    func sessionRecord(
        startTime: Date,
        endTime: Date? = nil,
        lastHeartBeat: Date? = nil,
        coldStart: Bool = false,
        processIdentifier: EmbraceIdentifier = ProcessIdentifier.current,
        traceId: TraceId = .random(),
        spanId: SpanId = .random()
    ) -> EmbraceSession {
        return storage.addSession(
            id: .random,
            processId: processIdentifier,
            state: .foreground,
            traceId: traceId.hexString,
            spanId: spanId.hexString,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartBeat ?? startTime,
            coldStart: coldStart
        )!
    }

    // MARK: Tests
    // MARK: - Spans
    func test_withoutAnySpans_returnsEmptyArray() throws {
        // session  :      ---------------
        // span     :
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )
        let results = storage.fetchSpans(for: session)
        XCTAssertTrue(results.isEmpty)
    }

    func test_withSpanBeforeSession_returnsEmptyArray() throws {
        // session  :      ---------------
        // span     :----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        _ = addSpanRecord(startTime: .relative(-30), endTime: .relative(-25))
        let results = storage.fetchSpans(for: session)

        XCTAssertTrue(results.isEmpty)
    }

    func test_withSpanBeforeSession_whenColdStart_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :|----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        let span = addSpanRecord(startTime: .relative(-30), endTime: .relative(-25))
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withSpanAfterSession_returnsEmptyArray() throws {
        // session  :      ---------------
        // span     :                       ----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        _ = addSpanRecord(startTime: .relative(-2), endTime: Date())
        let results = storage.fetchSpans(for: session)

        XCTAssertTrue(results.isEmpty)
    }

    func test_withSpanOverlapSessionStart_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :    ----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = addSpanRecord(startTime: .relative(-22), endTime: .relative(-18))
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withSpanOverlapsSessionEnd_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :                   ----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = addSpanRecord(startTime: .relative(-7), endTime: .relative(-2))
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withSpanOverlapsSessionEntirely_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :    --------------------
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10)
        )

        let span = addSpanRecord(startTime: .relative(-25), endTime: .relative(-5))
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    // MARK: - Test Open Spans
    func test_withOpenSpan_startedBeforeSession_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :    -------------------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = addSpanRecord(startTime: .relative(-22), endTime: nil)
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withOpenSpan_startedAfterSession_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :             -----------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = addSpanRecord(startTime: .relative(-10), endTime: nil)
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withOpenSpan_startedBeforeColdStartSession_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :    -------------------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        let span = addSpanRecord(startTime: .relative(-22), endTime: nil)
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withOpenSpan_startedAfterColdStartSession_returnsSpanInArray() throws {
        // session  :      ---------------
        // span     :             -----------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        let span = addSpanRecord(startTime: .relative(-10), endTime: nil)
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withOpenSpan_startedAfterColdStartSessionEnds_returnsEmptyArray() throws {
        // session  :      ---------------
        // span     :                       ---...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        _ = addSpanRecord(startTime: .relative(-2), endTime: nil)
        let results = storage.fetchSpans(for: session)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: Tests with irrelevant spans
    func test_withMultipleSpans_oneAfterColdStartSessionEnds_returnsRelevantSpansOnly() throws {
        // session  :      ---------------
        // span     :    -a--    -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: true
        )

        let spanA = addSpanRecord(name: "span-a", startTime: .relative(-22), endTime: .relative(-18))
        let spanB = addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12))
        let spanC = addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2))
        let results = storage.fetchSpans(for: session)

        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanA.context.spanId && $0.name == "span-a" }))
        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanB.context.spanId && $0.name == "span-b" }))
        XCTAssertNil(results.first(where: { $0.context.spanId == spanC.context.spanId && $0.name == "span-c" }))
    }

    func test_withMultipleSpans_oneBeforeColdStartSessionBegins_returnsRelevantSpansOnly() throws {
        // session  :      ---------------
        // span     : -a-         -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: true
        )

        let spanA = addSpanRecord(name: "span-a", startTime: .relative(-28), endTime: .relative(-22))
        let spanB = addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12))
        let spanC = addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2))
        let results = storage.fetchSpans(for: session)

        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanA.context.spanId && $0.name == "span-a" }))
        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanB.context.spanId && $0.name == "span-b" }))
        XCTAssertNil(results.first(where: { $0.context.spanId == spanC.context.spanId && $0.name == "span-c" }))
    }

    func test_withMultipleSpans_oneBeforeWarmStartSessionBegins_returnsRelevantSpansOnly() throws {
        // session  :      ---------------
        // span     : -a-         -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: false
        )

        let spanA = addSpanRecord(name: "span-a", startTime: .relative(-28), endTime: .relative(-22))
        let spanB = addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12))
        let spanC = addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2))
        let results = storage.fetchSpans(for: session)

        XCTAssertNil(results.first(where: { $0.context.spanId == spanA.context.spanId && $0.name == "span-a" }))
        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanB.context.spanId && $0.name == "span-b" }))
        XCTAssertNil(results.first(where: { $0.context.spanId == spanC.context.spanId && $0.name == "span-c" }))
    }

    // MARK: Tests when spans match session boundary
    func test_withSpanEndAtIsEqualToSessionStart_returnsEmptyArray() throws {
        // session  :      |---------------
        // span     :  ----|
        let boundary: Date = .relative(-20)

        let session = sessionRecord(
            startTime: boundary,
            endTime: .relative(-5)
        )

        let span = addSpanRecord(startTime: .relative(-30), endTime: boundary)
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withSpanEndAtIsEqualToSessionStart_whenColdStart_returnsSpan() throws {
        // session  :      |---------------
        // span     :  ----|
        let boundary: Date = .relative(-20)

        let session = sessionRecord(
            startTime: boundary,
            endTime: .relative(-5),
            coldStart: true
        )

        let span = addSpanRecord(startTime: .relative(-30), endTime: boundary)
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_withSpanStartAtIsEqualToSessionEnd_returnsEmptyArray() throws {
        // session  :      ---------------|
        // span     :                     |----
        let boundary: Date = .relative(-5)

        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: boundary
        )

        let span = addSpanRecord(startTime: boundary, endTime: .relative(0))
        let results = storage.fetchSpans(for: session)

        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_ignoreSessionSpanFlag_whenTrue_doesNotReturnSessionSpan() throws {
        // session  :      ---------------
        // span     :      ---------------
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10)
        )

        _ = addSpanRecord(
            type: .session,
            startTime: session.startTime,
            endTime: session.endTime
        )

        let results = storage.fetchSpans(for: session, ignoreSessionSpans: true)
        XCTAssertTrue(results.isEmpty)
    }

    func test_ignoreSessionSpanFlag_whenFalse_doesReturnSessionSpan() throws {
        // session  :      ---------------
        // span     :      ---------------
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10)
        )

        let span = addSpanRecord(
            type: .session,
            startTime: session.startTime,
            endTime: session.endTime
        )

        let results = storage.fetchSpans(for: session, ignoreSessionSpans: false)
        XCTAssertEqual(results[0].context.spanId, span.context.spanId)
    }

    func test_spansWithSessionId() throws {
        // session  :      ---------------
        // span     : -a-         -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: false
        )

        let spanA = addSpanRecord(
            name: "span-a",
            startTime: .relative(-28),
            endTime: .relative(-22),
            sessionIdentifier: session.id
        )
        let spanB = addSpanRecord(
            name: "span-b",
            startTime: .relative(-16),
            endTime: .relative(-12),
            sessionIdentifier: .random
        )
        let spanC = addSpanRecord(
            name: "span-c",
            startTime: .relative(-6),
            endTime: .relative(-2),
            sessionIdentifier: session.id
        )
        let results = storage.fetchSpans(for: session)

        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanA.context.spanId && $0.name == "span-a" }))
        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanB.context.spanId && $0.name == "span-b" }))
        XCTAssertNotNil(results.first(where: { $0.context.spanId == spanC.context.spanId && $0.name == "span-c" }))
    }
}
