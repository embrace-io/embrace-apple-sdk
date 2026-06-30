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
}
