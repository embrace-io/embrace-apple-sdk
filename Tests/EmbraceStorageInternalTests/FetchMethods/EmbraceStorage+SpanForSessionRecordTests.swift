//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi

fileprivate extension Date {
    static func relative(_ interval: TimeInterval, from reference: Date = Date()) -> Date {
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
        try storage.teardown()
    }

    func addSpanRecord(
        type: SpanType = .performance,
        name: String = "example",
        processIdentifier: ProcessIdentifier = .current,
        startTime: Date,
        endTime: Date? = nil,
        sessionIdentifier: SessionIdentifier? = nil
    ) throws -> SpanRecord {
        let span = SpanRecord(
            id: SpanId.random().hexString,
            name: name,
            traceId: TraceId.random().hexString,
            type: type,
            data: Data(),
            startTime: startTime,
            endTime: endTime,
            processIdentifier: processIdentifier,
            sessionIdentifier: sessionIdentifier
        )
        try storage.upsertSpan(span)

        return span
    }

    func sessionRecord(
        startTime: Date,
        endTime: Date? = nil,
        lastHeartBeat: Date? = nil,
        coldStart: Bool = false,
        processIdentifier: ProcessIdentifier = .current,
        traceId: TraceId = .random(),
        spanId: SpanId = .random()
    ) -> SessionRecord {
        return SessionRecord(
            id: .random,
            state: .foreground,
            processId: processIdentifier,
            traceId: traceId.hexString,
            spanId: spanId.hexString,
            startTime: startTime,
            endTime: endTime,
            lastHeartbeatTime: lastHeartBeat ?? startTime,
            coldStart: coldStart
        )
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
        let results = try storage.fetchSpans(for: session)
        XCTAssertTrue(results.isEmpty)
    }

    func test_withSpanBeforeSession_returnsEmptyArray() throws {
    // session  :      ---------------
    // span     :----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        _ = try addSpanRecord(startTime: .relative(-30), endTime: .relative(-25))
        let results = try storage.fetchSpans(for: session)

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

        let span = try addSpanRecord(startTime: .relative(-30), endTime: .relative(-25))
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withSpanAfterSession_returnsEmptyArray() throws {
    // session  :      ---------------
    // span     :                       ----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        _ = try addSpanRecord(startTime: .relative(-2), endTime: Date())
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.isEmpty)
    }

    func test_withSpanOverlapSessionStart_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :    ----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = try addSpanRecord(startTime: .relative(-22), endTime: .relative(-18))
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withSpanOverlapsSessionEnd_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :                   ----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = try addSpanRecord(startTime: .relative(-7), endTime: .relative(-2))
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withSpanOverlapsSessionEntirely_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :    --------------------
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10)
        )

        let span = try addSpanRecord(startTime: .relative(-25), endTime: .relative(-5))
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

// MARK: - Test Open Spans
    func test_withOpenSpan_startedBeforeSession_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :    -------------------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = try addSpanRecord(startTime: .relative(-22), endTime: nil)
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withOpenSpan_startedAfterSession_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :             -----------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5)
        )

        let span = try addSpanRecord(startTime: .relative(-10), endTime: nil)
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withOpenSpan_startedBeforeColdStartSession_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :    -------------------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        let span = try addSpanRecord(startTime: .relative(-22), endTime: nil)
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withOpenSpan_startedAfterColdStartSession_returnsSpanInArray() throws {
    // session  :      ---------------
    // span     :             -----------...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        let span = try addSpanRecord(startTime: .relative(-10), endTime: nil)
        let results = try storage.fetchSpans(for: session)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(span))
    }

    func test_withOpenSpan_startedAfterColdStartSessionEnds_returnsEmptyArray() throws {
    // session  :      ---------------
    // span     :                       ---...
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-5),
            coldStart: true
        )

        _ = try addSpanRecord(startTime: .relative(-2), endTime: nil)
        let results = try storage.fetchSpans(for: session)

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

        let spanA = try addSpanRecord(name: "span-a", startTime: .relative(-22), endTime: .relative(-18))
        let spanB = try addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12))
        let spanC = try addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2))
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.contains(spanA))
        XCTAssertTrue(results.contains(spanB))
        XCTAssertFalse(results.contains(spanC))
    }

    func test_withMultipleSpans_oneBeforeColdStartSessionBegins_returnsRelevantSpansOnly() throws {
    // session  :      ---------------
    // span     : -a-         -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: true
        )

        let spanA = try addSpanRecord(name: "span-a", startTime: .relative(-28), endTime: .relative(-22))
        let spanB = try addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12))
        let spanC = try addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2))
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.contains(spanA))
        XCTAssertTrue(results.contains(spanB))
        XCTAssertFalse(results.contains(spanC))
    }

    func test_withMultipleSpans_oneBeforeWarmStartSessionBegins_returnsRelevantSpansOnly() throws {
    // session  :      ---------------
    // span     : -a-         -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: false
        )

        let spanA = try addSpanRecord(name: "span-a", startTime: .relative(-28), endTime: .relative(-22))
        let spanB = try addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12))
        let spanC = try addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2))
        let results = try storage.fetchSpans(for: session)

        XCTAssertFalse(results.contains(spanA))
        XCTAssertTrue(results.contains(spanB))
        XCTAssertFalse(results.contains(spanC))
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

        let span = try addSpanRecord(startTime: .relative(-30), endTime: boundary)
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.contains(span))
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

        let span = try addSpanRecord(startTime: .relative(-30), endTime: boundary)
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.contains(span))
    }

    func test_withSpanStartAtIsEqualToSessionEnd_returnsEmptyArray() throws {
    // session  :      ---------------|
    // span     :                     |----
        let boundary: Date = .relative(-5)

        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: boundary
        )

        let span = try addSpanRecord(startTime: boundary, endTime: .relative(0))
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.contains(span))
    }

    func test_ignoreSessionSpanFlag_whenTrue_doesNotReturnSessionSpan() throws {
    // session  :      ---------------
    // span     :      ---------------
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10)
        )

        _ = try addSpanRecord(
            type: .session,
            startTime: session.startTime,
            endTime: session.endTime
        )

        let results = try storage.fetchSpans(for: session, ignoreSessionSpans: true)
        XCTAssertTrue(results.isEmpty)
    }

    func test_ignoreSessionSpanFlag_whenFalse_doesReturnSessionSpan() throws {
    // session  :      ---------------
    // span     :      ---------------
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10)
        )

        let span = try addSpanRecord(
            type: .session,
            startTime: session.startTime,
            endTime: session.endTime
        )

        let results = try storage.fetchSpans(for: session, ignoreSessionSpans: false)
        XCTAssertTrue(results.contains(span))
    }

    func test_spansWithSessionId() throws {
    // session  :      ---------------
    // span     : -a-         -b--           -c----
        let session = sessionRecord(
            startTime: .relative(-20),
            endTime: .relative(-10),
            coldStart: false
        )

        let spanA = try addSpanRecord(name: "span-a", startTime: .relative(-28), endTime: .relative(-22), sessionIdentifier: session.id)
        let spanB = try addSpanRecord(name: "span-b", startTime: .relative(-16), endTime: .relative(-12), sessionIdentifier: SessionIdentifier.random)
        let spanC = try addSpanRecord(name: "span-c", startTime: .relative(-6), endTime: .relative(-2), sessionIdentifier: session.id)
        let results = try storage.fetchSpans(for: session)

        XCTAssertTrue(results.contains(spanA))
        XCTAssertTrue(results.contains(spanB))
        XCTAssertTrue(results.contains(spanC))
    }
}
