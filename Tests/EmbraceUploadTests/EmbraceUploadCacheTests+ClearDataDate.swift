//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceUpload

extension EmbraceUploadCacheTests {
    func test_clearStaleDataIfNeeded_basedOn_date() throws {
        let testOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
        // setting the maximum allowed days
        testOptions.cacheDaysLimit = 15
        testOptions.cacheSizeLimit = 0
        let cache = try EmbraceUploadCache(options: testOptions)

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        let record1 = UploadDataRecord(
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: Date(timeInterval: -1300, since: now)
        )
        let record2 = UploadDataRecord(
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        let record3 = UploadDataRecord(
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        let record4 = UploadDataRecord(
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0,
            date: Date(timeInterval: -1200, since: now)
        )
        let record5 = UploadDataRecord(
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0,
            date: Date(timeInterval: -1100, since: now)
        )
        let record6 = UploadDataRecord(
            id: "id6",
            type: 0,
            data: Data(repeating: 3, count: 100),
            attemptCount: 0,
            date: Date(timeInterval: -1000, since: now)
        )

        try cache.dbQueue.write { db in
            try record1.insert(db)
            try record2.insert(db)
            try record3.insert(db)
            try record4.insert(db)
            try record5.insert(db)
            try record6.insert(db)
        }

        // when attempting to remove data over the allowed days
        let removedRecords = try cache.clearStaleDataIfNeeded()

        // the expected records should've been removed.
        let records = try cache.fetchAllUploadData()
        XCTAssertEqual(removedRecords, 2)
        XCTAssert(!records.contains(record2))
        XCTAssert(!records.contains(record3))
        XCTAssert(records.contains(record1))
        XCTAssert(records.contains(record4))
        XCTAssert(records.contains(record5))
        XCTAssert(records.contains(record6))
    }

    func test_clearStaleDataIfNeeded_basedOn_date_noLimit() throws {
        let testOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
        // disabling maximum allowed days
        testOptions.cacheDaysLimit = 0
        testOptions.cacheSizeLimit = 0
        let cache = try EmbraceUploadCache(options: testOptions)

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        let record1 = UploadDataRecord(
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0, date: Date(timeInterval: -1300, since: now)
        )
        let record2 = UploadDataRecord(
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0, date: oldDate
        )
        let record3 = UploadDataRecord(
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0, date: oldDate
        )
        let record4 = UploadDataRecord(
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0, date: Date(timeInterval: -1200, since: now)
        )
        let record5 = UploadDataRecord(
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0, date: Date(timeInterval: -1100, since: now)
        )
        let record6 = UploadDataRecord(
            id: "id6",
            type: 0,
            data: Data(repeating: 3, count: 100),
            attemptCount: 0,
            date: Date(timeInterval: -1000, since: now)
        )

        try cache.dbQueue.write { db in
            try record1.insert(db)
            try record2.insert(db)
            try record3.insert(db)
            try record4.insert(db)
            try record5.insert(db)
            try record6.insert(db)
        }

        // when attempting to remove data over the allowed days
        let removedRecords = try cache.clearStaleDataIfNeeded()

        // no records should've been removed
        let records = try cache.fetchAllUploadData()
        XCTAssertEqual(removedRecords, 0)
        XCTAssert(records.contains(record2))
        XCTAssert(records.contains(record3))
        XCTAssert(records.contains(record1))
        XCTAssert(records.contains(record4))
        XCTAssert(records.contains(record5))
        XCTAssert(records.contains(record6))
    }

    func test_clearStaleDataIfNeeded_basedOn_date_noRecords() throws {
        let testOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
        // setting minimum allowed time
        testOptions.cacheDaysLimit = 1
        testOptions.cacheSizeLimit = 0
        let cache = try EmbraceUploadCache(options: testOptions)

        // when attempting to remove data from an empty cache
        let removedRecords = try cache.clearStaleDataIfNeeded()

        // no records should've been removed
        XCTAssertEqual(removedRecords, 0)
    }

    func test_clearStaleDataIfNeeded_basedOn_date_didNotHitTimeLimit() throws {
        let testOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
        // disabling maximum allowed days
        testOptions.cacheDaysLimit = 17
        testOptions.cacheSizeLimit = 0
        let cache = try EmbraceUploadCache(options: testOptions)

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        let record1 = UploadDataRecord(
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: Date(timeInterval: -1300, since: now)
        )
        let record2 = UploadDataRecord(
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        let record3 = UploadDataRecord(
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        let record4 = UploadDataRecord(
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0,
            date: Date(timeInterval: -1200, since: now)
        )
        let record5 = UploadDataRecord(
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0,
            date: Date(timeInterval: -1100, since: now)
        )
        let record6 = UploadDataRecord(
            id: "id6",
            type: 0,
            data: Data(repeating: 3, count: 100),
            attemptCount: 0,
            date: Date(timeInterval: -1000, since: now)
        )

        try cache.dbQueue.write { db in
            try record1.insert(db)
            try record2.insert(db)
            try record3.insert(db)
            try record4.insert(db)
            try record5.insert(db)
            try record6.insert(db)
        }

        // when attempting to remove data over the allowed days
        let removedRecords = try cache.clearStaleDataIfNeeded()

        // no records should've been removed
        let records = try cache.fetchAllUploadData()
        XCTAssertEqual(removedRecords, 0)
        XCTAssert(records.contains(record2))
        XCTAssert(records.contains(record3))
        XCTAssert(records.contains(record1))
        XCTAssert(records.contains(record4))
        XCTAssert(records.contains(record5))
        XCTAssert(records.contains(record6))
    }

    func test_clearStaleDataIfNeeded_basedOn_size_and_date() throws {
        let testOptions = EmbraceUpload.CacheOptions(cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory()))!
        // setting both limits for days and size
        testOptions.cacheDaysLimit = 15
        testOptions.cacheSizeLimit = 1001
        let cache = try EmbraceUploadCache(options: testOptions)

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        let record1 = UploadDataRecord(
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: Date(timeInterval: -1300, since: now)
        )
        let record2 = UploadDataRecord(
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 10000),
            attemptCount: 0,
            date: oldDate
        )
        let record3 = UploadDataRecord(
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 10000),
            attemptCount: 0,
            date: oldDate
        )
        let record4 = UploadDataRecord(
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0,
            date: Date(timeInterval: -1200, since: now)
        )
        let record5 = UploadDataRecord(
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0,
            date: Date(timeInterval: -1100, since: now)
        )
        let record6 = UploadDataRecord(
            id: "id6",
            type: 0, data: Data(repeating: 3, count: 300), attemptCount: 0, date: Date(timeInterval: -1000, since: now)
        )

        try cache.dbQueue.write { db in
            try record1.insert(db)
            try record2.insert(db)
            try record3.insert(db)
            try record4.insert(db)
            try record5.insert(db)
            try record6.insert(db)
        }

        // when trying to remove both old records and after that, records that go over the size limit
        try cache.clearStaleDataIfNeeded()

        // the expected records should've been removed.
        let records = try cache.fetchAllUploadData()
        XCTAssert(!records.contains(record1))
        XCTAssert(!records.contains(record2))
        XCTAssert(!records.contains(record3))
        XCTAssert(records.contains(record4))
        XCTAssert(records.contains(record5))
        XCTAssert(records.contains(record6))
    }
}
