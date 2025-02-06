//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceStorageInternal
import OpenTelemetryApi

final class EmbraceStorage_SpanTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        try storage.teardown()
        storage = nil
    }

    func test_upsertSpan_appliesConfiguredLimitForType() throws {
        storage.options.spanLimits[.performance] = 3

        for i in 0..<3 {
            // given inserted record
            let span = SpanRecord(
                id: SpanId.random().hexString,
                name: "example \(i)",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )

            try storage.upsertSpan(span)
        }

        try storage.upsertSpan(
            SpanRecord(
                id: SpanId.random().hexString,
                name: "newest",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )
        )

        let allRecords = try storage.dbQueue.read { db in
            try SpanRecord.order(SpanRecord.Schema.startTime).fetchAll(db)
        }
        XCTAssertEqual(allRecords.count, 3)
        XCTAssertEqual(allRecords.map(\.name), ["example 1", "example 2", "newest"])
    }

    func test_upsertSpan_limitIsUniqueToSpecificType() throws {
        storage.options.spanLimits[.performance] = 3
        storage.options.spanLimits[.networkRequest] = 1

        // insert 3 .performance spans
        for i in 0..<3 {
            let span = SpanRecord(
                id: SpanId.random().hexString,
                name: "performance \(i)",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )

            try storage.upsertSpan(span)
        }

        // insert 3 .networkHTTP spans
        for i in 0..<3 {
            let span = SpanRecord(
                id: SpanId.random().hexString,
                name: "network \(i)",
                traceId: TraceId.random().hexString,
                type: .networkRequest,
                data: Data(),
                startTime: Date()
            )

            try storage.upsertSpan(span)
        }

        let allRecords = try storage.dbQueue.read { db in
            try SpanRecord.order(SpanRecord.Schema.startTime).fetchAll(db)
        }
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
        for i in 0..<(EmbraceStorage.defaultSpanLimitByType + 10) {
            // given inserted record
            let span = SpanRecord(
                id: SpanId.random().hexString,
                name: "example \(i)",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )

            try storage.upsertSpan(span)
        }

        try storage.upsertSpan(
            SpanRecord(
                id: SpanId.random().hexString,
                name: "newest",
                traceId: TraceId.random().hexString,
                type: .performance,
                data: Data(),
                startTime: Date()
            )
        )

        let allRecords = try storage.dbQueue.read { db in
            try SpanRecord.order(SpanRecord.Schema.startTime).fetchAll(db)
        }
        XCTAssertEqual(allRecords.count, EmbraceStorage.defaultSpanLimitByType) // 1500 is default limit
    }

}
