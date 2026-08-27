//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

/// Tests that the `EmbraceOTelDelegate` conformance (`onStartSpan`, `onEndSpan`, `onEmitLog`)
/// applies the full sanitisation pipeline before persisting external signals to storage.
/// Uses the real `DefaultOtelSignalsSanitizer` and `DefaultOtelSignalsLimiter` with
/// small custom limits so truncation and capping behaviour is deterministic.
class DefaultOTelSignalsDelegateSanitizationTests: XCTestCase {

    var handler: DefaultOTelSignalsHandler!
    var sessionController: MockSessionController!
    var logController: LogController!
    var bridge: MockOTelSignalBridge!
    var storage: EmbraceStorage!
    var upload: SpyEmbraceLogUploader!

    // Tight limits applied to every test in this class.
    static let spanNameLength = 5
    static let spanAttributeCount = 2
    static let keyLength = 3
    static let valueLength = 5
    static let eventCount = 2
    static let linkCount = 2
    static let logAttributeCount = 2

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        upload = SpyEmbraceLogUploader()

        sessionController = MockSessionController()
        sessionController.storage = storage

        logController = LogController(
            storage: storage,
            upload: upload,
            sessionController: sessionController,
            queue: .main
        )

        bridge = MockOTelSignalBridge()

        let sessionLimits = SessionLimits(
            customSpans: SessionLimits.SpanLimits(
                count: 500,
                nameLength: Self.spanNameLength,
                attributeCount: Self.spanAttributeCount
            ),
            events: SessionLimits.SpanEventLimits(
                customSpanEventCount: Self.eventCount,
                nameLength: 128,
                typeLimits: nil,
                attributeCount: 10
            ),
            links: SessionLimits.SpanLinkLimits(
                customSpanLinkCount: Self.linkCount,
                attributeCount: 10
            ),
            logs: SessionLimits.LogLimits(
                attributeCount: Self.logAttributeCount
            )
        )

        let attributeLimits = AttributeLimits(
            keyLength: Self.keyLength,
            valueLength: Self.valueLength
        )

        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: sessionLimits,
            attributeLimits: attributeLimits
        )
        let limiter = DefaultOtelSignalsLimiter(sessionLimits: sessionLimits)

        handler = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: logController,
            limiter: limiter,
            sanitizer: sanitizer,
            bridge: bridge
        )

        sessionController.spanHandler = handler
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        storage = nil
        upload = nil
        sessionController = nil
        logController = nil
        bridge = nil
        handler = nil
    }

    // MARK: - onStartSpan

    func test_onStartSpan_sanitizesSpanName() throws {
        // given a span with a name longer than the configured limit (5)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "123456789"
        )

        // when the span starts
        handler.onStartSpan(span)

        // then the name is truncated in storage
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)
        XCTAssertEqual(record!.name, "12345")
    }

    func test_onStartSpan_capsAttributeCount() throws {
        // given a span with more attributes than the limit (2)
        // keys sorted alphabetically: aaa, bbb, ccc, ddd → only aaa and bbb survive
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            attributes: ["aaa": "1", "bbb": "2", "ccc": "3", "ddd": "4"]
        )

        // when the span starts
        handler.onStartSpan(span)

        // then only the first 2 attributes (sorted by key) are stored
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.attributes["aaa"] as! String, "1")
        XCTAssertEqual(record.attributes["bbb"] as! String, "2")
        XCTAssertNil(record.attributes["ccc"])
        XCTAssertNil(record.attributes["ddd"])
    }

    func test_onStartSpan_truncatesAttributeKey() throws {
        // given a span with an attribute key longer than the limit (3)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            attributes: ["longkey": "value"]
        )

        // when the span starts
        handler.onStartSpan(span)

        // then the key is truncated to 3 characters in storage
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertNotNil(record.attributes["lon"])
        XCTAssertNil(record.attributes["longkey"])
    }

    func test_onStartSpan_truncatesAttributeValue() throws {
        // given a span with an attribute value longer than the limit (5)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            attributes: ["key": "longvalue"]
        )

        // when the span starts
        handler.onStartSpan(span)

        // then the value is truncated to 5 characters in storage
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.attributes["key"] as! String, "longv")
    }

    func test_onStartSpan_capsEventCount() throws {
        // given a span with more events than the limit (2)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            events: [
                EmbraceSpanEvent(name: "event1"),
                EmbraceSpanEvent(name: "event2"),
                EmbraceSpanEvent(name: "event3"),
                EmbraceSpanEvent(name: "event4")
            ]
        )

        // when the span starts
        handler.onStartSpan(span)

        // then only the first 2 events are stored (storage may return them in any order)
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        let eventNames = record.events.map(\.name)
        XCTAssertEqual(record.events.count, 2)
        XCTAssertTrue(eventNames.contains("event1"))
        XCTAssertTrue(eventNames.contains("event2"))
        XCTAssertFalse(eventNames.contains("event3"))
        XCTAssertFalse(eventNames.contains("event4"))
    }

    func test_onStartSpan_capsLinkCount() throws {
        // given a span with more links than the limit (2)
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            links: [
                EmbraceSpanLink(spanId: "span1", traceId: "trace1"),
                EmbraceSpanLink(spanId: "span2", traceId: "trace2"),
                EmbraceSpanLink(spanId: "span3", traceId: "trace3"),
                EmbraceSpanLink(spanId: "span4", traceId: "trace4")
            ]
        )

        // when the span starts
        handler.onStartSpan(span)

        // then only the first 2 links are stored (storage may return them in any order)
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        let linkSpanIds = record.links.map(\.context.spanId)
        XCTAssertEqual(record.links.count, 2)
        XCTAssertTrue(linkSpanIds.contains("span1"))
        XCTAssertTrue(linkSpanIds.contains("span2"))
        XCTAssertFalse(linkSpanIds.contains("span3"))
        XCTAssertFalse(linkSpanIds.contains("span4"))
    }

    func test_onStartSpan_preservesProtectedKeys() throws {
        // given a span whose attributes exceed the count limit (2)
        // but also contain the three bridge-injected protected keys
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            attributes: [
                "aaa": "1",
                "bbb": "2",
                "ccc": "3",  // would be dropped by count limit
                SpanSemantics.keyEmbraceType: "perf",  // protected
                SpanSemantics.Session.keyState: "foreground",  // protected
                SpanSemantics.keySessionId: "sess123"  // protected
            ]
        )

        // when the span starts
        handler.onStartSpan(span)

        // then all three protected keys are present regardless of the count limit
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.attributes[SpanSemantics.keyEmbraceType] as! String, "perf")
        XCTAssertEqual(record.attributes[SpanSemantics.Session.keyState] as! String, "foreground")
        XCTAssertEqual(record.attributes[SpanSemantics.keySessionId] as! String, "sess123")
        // and the overflow non-protected attribute is absent
        XCTAssertNil(record.attributes["ccc"])
    }

    // MARK: - onEndSpan

    func test_onEndSpan_sanitizesSpanName() throws {
        // given a span already in storage with a long name
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "123456789"
        )
        storage.upsertSpan(span)

        // when the span ends
        handler.onEndSpan(span)

        // then the name is truncated in storage
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.name, "12345")
    }

    func test_onEndSpan_preservesProtectedKeys() throws {
        // given a span already in storage whose attributes exceed the count limit
        // and include the three bridge-injected protected keys
        let span = MockSpan(
            id: TestConstants.spanId,
            traceId: TestConstants.traceId,
            name: "test",
            attributes: [
                "aaa": "1",
                "bbb": "2",
                "ccc": "3",  // would be dropped by count limit
                SpanSemantics.keyEmbraceType: "perf",  // protected
                SpanSemantics.Session.keyState: "foreground",  // protected
                SpanSemantics.keySessionId: "sess123"  // protected
            ]
        )
        storage.upsertSpan(span)

        // when the span ends
        handler.onEndSpan(span)

        // then all three protected keys are still present
        let record = storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId)!
        XCTAssertEqual(record.attributes[SpanSemantics.keyEmbraceType] as! String, "perf")
        XCTAssertEqual(record.attributes[SpanSemantics.Session.keyState] as! String, "foreground")
        XCTAssertEqual(record.attributes[SpanSemantics.keySessionId] as! String, "sess123")
        XCTAssertNil(record.attributes["ccc"])
    }

    // MARK: - onEmitLog

    func test_onEmitLog_capsAttributeCount() throws {
        // given a log with more attributes than the limit (2)
        // keys sorted alphabetically: aaa, bbb, ccc, ddd → only aaa and bbb survive
        let log = MockLog(attributes: ["aaa": "1", "bbb": "2", "ccc": "3", "ddd": "4"])

        // when the log is emitted
        handler.onEmitLog(log)

        // then only the first 2 attributes (sorted by key) are stored
        wait(delay: .defaultTimeout)
        let record = storage.fetchAllLogs()[0]
        XCTAssertEqual(record.attributes["aaa"] as! String, "1")
        XCTAssertEqual(record.attributes["bbb"] as! String, "2")
        XCTAssertNil(record.attributes["ccc"])
        XCTAssertNil(record.attributes["ddd"])
    }

    func test_onEmitLog_truncatesAttributeKey() throws {
        // given a log with an attribute key longer than the limit (3)
        let log = MockLog(attributes: ["longkey": "value"])

        // when the log is emitted
        handler.onEmitLog(log)

        // then the key is truncated to 3 characters in storage
        wait(delay: .defaultTimeout)
        let record = storage.fetchAllLogs()[0]
        XCTAssertNotNil(record.attributes["lon"])
        XCTAssertNil(record.attributes["longkey"])
    }

    func test_onEmitLog_truncatesAttributeValue() throws {
        // given a log with an attribute value longer than the limit (5)
        let log = MockLog(attributes: ["key": "longvalue"])

        // when the log is emitted
        handler.onEmitLog(log)

        // then the value is truncated to 5 characters in storage
        wait(delay: .defaultTimeout)
        let record = storage.fetchAllLogs()[0]
        XCTAssertEqual(record.attributes["key"] as! String, "longv")
    }

    func test_onEmitLog_preservesProtectedKeys() throws {
        // given a log whose attributes exceed the count limit (2)
        // and include the three bridge-injected protected keys
        let log = MockLog(attributes: [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            LogSemantics.keyEmbraceType: "sys.log",  // protected
            LogSemantics.keyState: "foreground",  // protected
            LogSemantics.keySessionId: "sess123"  // protected
        ])

        // when the log is emitted
        handler.onEmitLog(log)

        // then all three protected keys are present regardless of the count limit
        wait(delay: .defaultTimeout)
        let record = storage.fetchAllLogs()[0]
        XCTAssertEqual(record.attributes[LogSemantics.keyEmbraceType] as! String, "sys.log")
        XCTAssertEqual(record.attributes[LogSemantics.keyState] as! String, "foreground")
        XCTAssertEqual(record.attributes[LogSemantics.keySessionId] as! String, "sess123")
        XCTAssertNil(record.attributes["ccc"])
    }
}
