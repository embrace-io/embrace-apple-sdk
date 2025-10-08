//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceOTelInternal
import TestSupport
import XCTest

@testable import EmbraceUploadInternal

class EmbraceUploadCacheTests: XCTestCase {
    let logger = MockLogger()
    var spanProcessor: MockSpanProcessor!
    let fileProvider = TemporaryFilepathProvider()

    override func setUpWithError() throws {
        spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
    }

    override func tearDownWithError() throws {

    }

    func test_resetCache() throws {

        // create the base folder as sometimes it might not exist
        try FileManager.default.createDirectory(at: fileProvider.tmpDirectory, withIntermediateDirectories: true)

        // given an existing db file
        let storageMechanism: StorageMechanism = .onDisk(
            name: "test_resetCache", baseURL: fileProvider.tmpDirectory, journalMode: .delete)
        let fileUrl = storageMechanism.fileURL!
        try "test".write(to: fileUrl, atomically: true, encoding: .utf8)
        XCTAssert(FileManager.default.fileExists(atPath: fileUrl.path))

        // when creating the cache with the reset flag enabled
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, resetCache: true)
        _ = try EmbraceUploadCache(options: options, logger: logger)

        // then the old cache file is deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))
    }

    func test_fetchUploadData() throws {
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false)
        let cache = try EmbraceUploadCache(options: options, logger: logger)

        // given inserted upload data
        let original = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id",
            type: EmbraceUploadType.spans.rawValue,
            data: Data(),
            payloadTypes: "test",
            attemptCount: 0,
            date: Date()
        )

        cache.coreData.save()

        // when fetching the upload data
        let uploadData = cache.fetchUploadData(id: "id", type: .spans)

        // then the upload data should be valid
        XCTAssertNotNil(uploadData)
        XCTAssertEqual(original, uploadData)
    }

    func test_fetchAllUploadData() throws {
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false)
        let cache = try EmbraceUploadCache(options: options, logger: logger)

        // given inserted upload datas
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id1",
            type: 0,
            data: Data(),
            payloadTypes: "test",
            attemptCount: 0,
            date: Date()
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id2",
            type: 0,
            data: Data(),
            payloadTypes: "test",
            attemptCount: 0,
            date: Date()
        )
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id3",
            type: 0,
            data: Data(),
            payloadTypes: "test",
            attemptCount: 0,
            date: Date()
        )

        cache.coreData.save()

        // when fetching the upload datas
        let datas = cache.fetchAllUploadData()

        // then the fetched datas are valid
        XCTAssertNotNil(datas.first(where: { $0.id == "id1" }))
        XCTAssertNotNil(datas.first(where: { $0.id == "id2" }))
        XCTAssertNotNil(datas.first(where: { $0.id == "id3" }))
    }

    func test_saveUploadData() throws {
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false)
        let cache = try EmbraceUploadCache(options: options, logger: logger)

        // given inserted upload data
        _ = cache.saveUploadData(id: "id", type: .spans, data: Data())

        // then the upload data should exist
        let expectation = XCTestExpectation()

        let request = NSFetchRequest<UploadDataRecord>(entityName: UploadDataRecord.entityName)
        request.predicate = NSPredicate(format: "id == %@ AND type == %i", "id", EmbraceUploadType.spans.rawValue)

        cache.coreData.context.perform {
            do {
                let result = try cache.coreData.context.fetch(request)
                if result.count > 0 {
                    expectation.fulfill()
                }
            } catch {}
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_saveUploadData_limit() throws {
        // given a cache with a limit of 1
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false, cacheLimit: 1)
        let cache = try EmbraceUploadCache(options: options, logger: logger)

        // given inserted upload datas
        _ = cache.saveUploadData(id: "id1", type: .spans, data: Data())
        _ = cache.saveUploadData(id: "id2", type: .spans, data: Data())
        _ = cache.saveUploadData(id: "id3", type: .spans, data: Data())

        // then only the last data should exist
        let expectation = XCTestExpectation()

        let request = NSFetchRequest<UploadDataRecord>(entityName: UploadDataRecord.entityName)

        cache.coreData.context.perform {
            do {
                let result = try cache.coreData.context.fetch(request)
                if result.count == 1,
                    result.first?.id == "id3"
                {
                    expectation.fulfill()
                }
            } catch {}
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_deleteUploadData() throws {
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false)
        let cache = try EmbraceUploadCache(options: options, logger: logger)

        // given inserted upload data
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id",
            type: EmbraceUploadType.spans.rawValue,
            data: Data(),
            payloadTypes: "test",
            attemptCount: 0,
            date: Date()
        )

        cache.coreData.save()

        // when deleting the data
        cache.deleteUploadData(id: "id", type: .spans)

        // then the upload data should not exist
        let expectation = XCTestExpectation()

        let request = NSFetchRequest<UploadDataRecord>(entityName: UploadDataRecord.entityName)

        cache.coreData.context.perform {
            do {
                let result = try cache.coreData.context.fetch(request)
                if result.count == 0 {
                    expectation.fulfill()
                }
            } catch {}
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_updateAttemptCount() throws {
        let options = EmbraceUpload.CacheOptions(
            storageMechanism: .inMemory(name: testName), enableBackgroundTasks: false)
        let cache = try EmbraceUploadCache(options: options, logger: logger)

        // given inserted upload data
        _ = UploadDataRecord.create(
            context: cache.coreData.context,
            id: "id",
            type: EmbraceUploadType.spans.rawValue,
            data: Data(),
            payloadTypes: "test",
            attemptCount: 0,
            date: Date()
        )

        cache.coreData.save()

        // when updating the attempt count
        cache.updateAttemptCount(id: "id", type: .spans, attemptCount: 10)

        // then the data is updated successfully
        let expectation = XCTestExpectation()

        let request = NSFetchRequest<UploadDataRecord>(entityName: UploadDataRecord.entityName)

        cache.coreData.context.perform {
            do {
                let result = try cache.coreData.context.fetch(request)
                if result.count == 1,
                    result.first?.id == "id",
                    result.first?.attemptCount == 10
                {
                    expectation.fulfill()
                }
            } catch {}
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
