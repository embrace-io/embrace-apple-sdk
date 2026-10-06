//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceStorageInternal

final class EmbraceStorage_SpanTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
    }

    func test_upsertSpan_appliesConfiguredLimitForType() throws {
        storage.options.spanLimits[.performance] = 3

        for i in 0..<3 {
            // given inserted record
            storage.upsertSpan(
                MockSpan(
                    name: "example \(i)",
                ))
        }

        storage.upsertSpan(
            MockSpan(
                name: "newest",
            ))

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, 3)
        XCTAssertEqual(allRecords.map(\.name), ["example 1", "example 2", "newest"])
    }

    func test_upsertSpan_limitIsUniqueToSpecificType() throws {
        storage.options.spanLimits[.performance] = 3
        storage.options.spanLimits[.networkRequest] = 1

        // insert 3 .performance spans
        for i in 0..<3 {
            storage.upsertSpan(
                MockSpan(
                    name: "performance \(i)",
                ))
        }

        // insert 3 .networkHTTP spans
        for i in 0..<3 {
            storage.upsertSpan(
                MockSpan(
                    name: "network \(i)",
                    type: .networkRequest,
                ))
        }

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, 4)
        XCTAssertEqual(
            allRecords.map(\.name),
            [
                "performance 0",
                "performance 1",
                "performance 2",
                "network 2"
            ]
        )
    }

    func test_upsertSpan_appliesDefaultLimit() throws {

        let oldLimitDefault = storage.options.spanLimitDefault
        storage.options.spanLimitDefault = 3
        defer {
            storage.options.spanLimitDefault = oldLimitDefault
        }

        for i in 0..<(storage.options.spanLimitDefault + 1) {
            // given inserted record
            storage.upsertSpan(
                MockSpan(
                    name: "example \(i)",
                ))
        }

        storage.upsertSpan(
            MockSpan(
                name: "newest",
            ))

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, storage.options.spanLimitDefault)
    }

    func test_upsertSpan_limitForType_doesNotEvictDeeperTypeSharingPrefix() throws {
        // `.performance` (raw "performance") is a prefix of `.networkRequest`
        // (raw "performance.network_request"). Enforcing the small `.performance` limit must NOT
        // count or evict network-request spans, which keep their own (default 1500) limit.
        storage.options.spanLimits[.performance] = 3

        let base = Date(timeIntervalSince1970: 0)

        // three OLDER network-request spans (deeper type that shares the "performance" prefix)
        for i in 0..<3 {
            storage.upsertSpan(
                MockSpan(
                    name: "network \(i)",
                    type: .networkRequest,
                    startTime: base.addingTimeInterval(TimeInterval(i))
                ))
        }

        // one NEWER bare `.performance` span — enforcing its limit of 3 should not touch the network spans
        storage.upsertSpan(
            MockSpan(
                name: "performance",
                type: .performance,
                startTime: base.addingTimeInterval(100)
            ))

        let request = SpanRecord.createFetchRequest()
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, 4)
        XCTAssertEqual(
            Set(allRecords.map(\.name)),
            ["network 0", "network 1", "network 2", "performance"]
        )
    }

    // MARK: - upsertSpanAsync

    func test_upsertSpanAsync_storesNewSpan() throws {
        let span = MockSpan(name: "example", attributes: ["key": "value"])

        storage.upsertSpanAsync(span)

        // sync fetches run on the same serial context, so they wait for the async insert
        let record = try XCTUnwrap(storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId))
        XCTAssertEqual(record.name, "example")
        XCTAssertEqual(record.attributes["key"] as? String, "value")
    }

    func test_upsertSpanAsync_onlyUpdate_doesNotInsertNewSpan() throws {
        let span = MockSpan(name: "example")

        storage.upsertSpanAsync(span, onlyUpdate: true)

        XCTAssertNil(storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId))
    }

    func test_upsertSpanAsync_onlyUpdate_updatesExistingSpan() throws {
        let span = MockSpan(name: "example")
        storage.upsertSpan(span)

        span.name = "updated"
        storage.upsertSpanAsync(span, onlyUpdate: true)

        let record = try XCTUnwrap(storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId))
        XCTAssertEqual(record.name, "updated")
    }

    func test_upsertSpanAsync_appliesConfiguredLimitForType() throws {
        storage.options.spanLimits[.performance] = 2

        let base = Date()
        for i in 0..<3 {
            storage.upsertSpanAsync(MockSpan(name: "example \(i)", startTime: base.addingTimeInterval(Double(i))))
        }

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.map(\.name), ["example 1", "example 2"])
    }

    func test_upsertSpanAsync_storesSpanStateAtCallTime() throws {
        let span = MockSpan(name: "example")

        // hold the context queue so the insert can only run after the span is mutated
        let gate = DispatchSemaphore(value: 0)
        storage.coreData.context.perform {
            gate.wait()
        }

        storage.upsertSpanAsync(span)

        // mutate the span and persist the change through its own operation, like the SDK does
        let event = try XCTUnwrap(span.addEvent(name: "event", type: nil, timestamp: Date(), attributes: [:]))
        storage.addSpanEvent(id: span.context.spanId, traceId: span.context.traceId, event: event)

        gate.signal()

        // the event must be stored once, not duplicated by the insert reading the mutated span
        let record = try XCTUnwrap(storage.fetchSpan(id: span.context.spanId, traceId: span.context.traceId))
        XCTAssertEqual(record.events.count, 1)
        XCTAssertEqual(record.events.first?.name, "event")
    }
}
