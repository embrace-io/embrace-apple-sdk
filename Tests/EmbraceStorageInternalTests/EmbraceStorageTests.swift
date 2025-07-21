//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

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
        storage.upsertSpan(
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
        XCTAssertNotNil(spans.first(where: { $0.name == "a name" }))
        let span = spans[0]

        // when deleting record
        storage.delete(span)

        // then record should not exist in storage
        spans = storage.fetchAll()
        XCTAssertEqual(spans.count, 0)
    }

    func test_fetchAll() throws {
        // given inserted records
        storage.upsertSpan(
            id: "id1",
            name: "a name 1",
            traceId: "traceId",
            type: .performance,
            data: Data(),
            startTime: Date()
        )
        storage.upsertSpan(
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
        XCTAssertNotNil(records.first(where: { $0.id == "id1" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id2" }))
    }
}
