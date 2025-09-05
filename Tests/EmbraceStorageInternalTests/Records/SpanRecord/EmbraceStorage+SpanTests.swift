//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
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
                id: SpanId.random().hexString,
                traceId: TraceId.random().hexString,
                name: "example \(i)",
                type: .performance,
                startTime: Date()
            )
        }

        storage.upsertSpan(
            id: SpanId.random().hexString,
            traceId: TraceId.random().hexString,
            name: "newest",
            type: .performance,
            startTime: Date()
        )

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
                id: SpanId.random().hexString,
                traceId: TraceId.random().hexString,
                name: "performance \(i)",
                type: .performance,
                startTime: Date()
            )
        }

        // insert 3 .networkHTTP spans
        for i in 0..<3 {
            storage.upsertSpan(
                id: SpanId.random().hexString,
                traceId: TraceId.random().hexString,
                name: "network \(i)",
                type: .networkRequest,
                startTime: Date()
            )
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
                id: SpanId.random().hexString,
                traceId: TraceId.random().hexString,
                name: "example \(i)",
                type: .performance,
                startTime: Date()
            )
        }

        storage.upsertSpan(
            id: SpanId.random().hexString,
            traceId: TraceId.random().hexString,
            name: "newest",
            type: .performance,
            startTime: Date()
        )

        let request = SpanRecord.createFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        let allRecords: [SpanRecord] = storage.coreData.fetch(withRequest: request)

        XCTAssertEqual(allRecords.count, storage.options.spanLimitDefault)
    }

}
