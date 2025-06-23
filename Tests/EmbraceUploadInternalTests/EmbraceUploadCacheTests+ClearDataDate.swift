//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceUploadInternal
import EmbraceCommonInternal

extension EmbraceUploadCacheTests {
    func test_clearStaleDataIfNeeded_basedOn_date() throws {
        // setting the maximum allowed days
        let options = EmbraceUpload.CacheOptions(storageMechanism: .inMemory(name: (testName)), enableBackgroundTasks: false, cacheDaysLimit: 15)
        let cache = try EmbraceUploadCache(options: options, logger: MockLogger())

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: Date(timeInterval: -1300, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0,
            date: Date(timeInterval: -1200, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0,
            date: Date(timeInterval: -1100, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id6",
            type: 0,
            data: Data(repeating: 3, count: 100),
            attemptCount: 0,
            date: Date(timeInterval: -1000, since: now)
        )

        cache.coreData.context.performAndWait {
            do {
                try cache.coreData.context.save()
            } catch { }
        }

        // when attempting to remove data over the allowed days
        let removedRecords = cache.clearStaleDataIfNeeded()

        // the expected records should've been removed.
        let records = cache.fetchAllUploadData()
        XCTAssertEqual(removedRecords, 2)
        XCTAssertNotNil(records.first(where: { $0.id == "id1" }))
        XCTAssertNil(records.first(where: { $0.id == "id2" }))
        XCTAssertNil(records.first(where: { $0.id == "id3" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id4" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id5" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id6" }))

        // make sure the vacuum performance span was added
        let spans = spanProcessor.endedSpans
        XCTAssertEqual(spans.count, 1)
        let vacuumSpan = spans[0]
        XCTAssertEqual(vacuumSpan.name, "emb-upload-cache-vacuum")
        XCTAssertEqual(vacuumSpan.embType, .performance)
        XCTAssertEqual(vacuumSpan.attributes["emb.private"], .string("true"))
        XCTAssertEqual(vacuumSpan.attributes["removed"], .string("2"))
        XCTAssertNotNil(vacuumSpan.endTime)
    }

    func test_clearStaleDataIfNeeded_basedOn_date_noLimit() throws {
        // disabling maximum allowed days
        let options = EmbraceUpload.CacheOptions(storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false, cacheDaysLimit: 0)
        let cache = try EmbraceUploadCache(options: options, logger: MockLogger())

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0, date: Date(timeInterval: -1300, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0, date: oldDate
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0, date: oldDate
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0, date: Date(timeInterval: -1200, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0, date: Date(timeInterval: -1100, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id6",
            type: 0,
            data: Data(repeating: 3, count: 100),
            attemptCount: 0,
            date: Date(timeInterval: -1000, since: now)
        )

        cache.coreData.context.performAndWait {
            do {
                try cache.coreData.context.save()
            } catch { }
        }

        // when attempting to remove data over the allowed days
        let removedRecords = cache.clearStaleDataIfNeeded()

        // no records should've been removed
        let records = cache.fetchAllUploadData()
        XCTAssertEqual(removedRecords, 0)
        XCTAssertNotNil(records.first(where: { $0.id == "id1" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id2" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id3" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id4" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id5" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id6" }))
    }

    func test_clearStaleDataIfNeeded_basedOn_date_noRecords() throws {
        // setting minimum allowed time
        let options = EmbraceUpload.CacheOptions(storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false, cacheDaysLimit: 1)
        let cache = try EmbraceUploadCache(options: options, logger: MockLogger())

        // when attempting to remove data from an empty cache
        let removedRecords = cache.clearStaleDataIfNeeded()

        // no records should've been removed
        XCTAssertEqual(removedRecords, 0)
    }

    func test_clearStaleDataIfNeeded_basedOn_date_didNotHitTimeLimit() throws {
        // disabling maximum allowed days
        let options = EmbraceUpload.CacheOptions(storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false, cacheDaysLimit: 17)
        let cache = try EmbraceUploadCache(options: options, logger: MockLogger())

        // given some upload cache
        let oldDate = Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        let now = Date()
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id1",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: Date(timeInterval: -1300, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id2",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id3",
            type: 0,
            data: Data(repeating: 3, count: 1),
            attemptCount: 0,
            date: oldDate
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id4",
            type: 0,
            data: Data(repeating: 3, count: 300),
            attemptCount: 0,
            date: Date(timeInterval: -1200, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id5",
            type: 0,
            data: Data(repeating: 3, count: 400),
            attemptCount: 0,
            date: Date(timeInterval: -1100, since: now)
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id6",
            type: 0,
            data: Data(repeating: 3, count: 100),
            attemptCount: 0,
            date: Date(timeInterval: -1000, since: now)
        )

        cache.coreData.context.performAndWait {
            do {
                try cache.coreData.context.save()
            } catch { }
        }

        // when attempting to remove data over the allowed days
        let removedRecords = cache.clearStaleDataIfNeeded()

        // no records should've been removed
        let records = cache.fetchAllUploadData()
        XCTAssertEqual(removedRecords, 0)
        XCTAssertNotNil(records.first(where: { $0.id == "id1" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id2" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id3" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id4" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id5" }))
        XCTAssertNotNil(records.first(where: { $0.id == "id6" }))
    }
}
