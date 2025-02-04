//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceStorageInternal

class EmbraceStorageTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

    func test_delete() throws {
        // given inserted record
        let span = storage.upsertSpan(
            id: "id",
            name: "a name",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // then record should exist in storage
        var spans: [SpanRecord] = storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertNotNil(spans.first(where: { $0.name == "a name"}))

        // when deleting record
        storage.delete(span)

        // then record should not exist in storage
        spans = storage.fetchAll()
        XCTAssertEqual(spans.count, 0)
    }

    func test_fetchAll() throws {
        // given inserted records
        let span1 = storage.upsertSpan(
            id: "id1",
            name: "a name 1",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )
        let span2 = storage.upsertSpan(
            id: "id2",
            name: "a name 2",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )

        // when fetching all records
        let records: [SpanRecord] = storage.fetchAll()

        // then all records should be successfully fetched
        XCTAssert(records.count == 2)
        XCTAssert(records.contains(span1))
        XCTAssert(records.contains(span2))
    }
}
